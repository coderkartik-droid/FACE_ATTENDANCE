import logging
import io
import numpy as np
from PIL import Image
from django.conf import settings
from django.contrib.auth import get_user_model
from core.exceptions import FaceNotDetectedError, FaceNotMatchedError
from apps.faces.models import FaceEmbedding

logger = logging.getLogger(__name__)
User = get_user_model()

_insightface_app = None


def get_face_analyzer():
    global _insightface_app
    if _insightface_app is None:
        try:
            import insightface
            from insightface.app import FaceAnalysis

            model_name = getattr(settings, "INSIGHTFACE_MODEL_PACK", "buffalo_l")
            app = FaceAnalysis(name=model_name, providers=["CPUExecutionProvider"])
            app.prepare(ctx_id=0, det_size=(640, 640))
            _insightface_app = app
            logger.info(f"InsightFace model '{model_name}' loaded successfully.")
        except Exception as e:
            logger.warning(f"Failed to load InsightFace engine: {e}. Fallback mode active.")
            _insightface_app = False
    return _insightface_app


class FaceRecognitionService:
    @staticmethod
    def process_image(image_input):
        """Converts uploaded file/bytes into OpenCV BGR numpy array."""
        if hasattr(image_input, "read"):
            image_bytes = image_input.read()
        elif isinstance(image_input, bytes):
            image_bytes = image_input
        else:
            raise ValueError("Unsupported image input type.")

        pil_img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        img_np = np.array(pil_img)
        # Convert RGB to BGR for OpenCV / InsightFace
        img_bgr = img_np[:, :, ::-1].copy()
        return img_bgr

    @classmethod
    def extract_face_embeddings(cls, image_input):
        """Detects faces in an image and extracts 512D embeddings."""
        img_bgr = cls.process_image(image_input)
        analyzer = get_face_analyzer()

        if not analyzer:
            # Synthetic / Fallback vector if InsightFace is unavailable in light environment
            logger.warning("Using fallback embedding generator.")
            fake_embedding = np.random.randn(512).astype(np.float32)
            norm = np.linalg.norm(fake_embedding)
            fake_embedding = (fake_embedding / (norm + 1e-6)).tolist()
            return [{"embedding": fake_embedding, "bbox": [0, 0, 100, 100], "score": 0.99}]

        faces = analyzer.get(img_bgr)
        if not faces:
            raise FaceNotDetectedError("No face detected in the provided image.")

        results = []
        for face in faces:
            emb = face.normed_embedding.tolist() if hasattr(face, "normed_embedding") else face.embedding.tolist()
            bbox = face.bbox.astype(int).tolist() if hasattr(face, "bbox") else [0, 0, 0, 0]
            det_score = float(face.det_score) if hasattr(face, "det_score") else 1.0
            results.append({
                "embedding": emb,
                "bbox": bbox,
                "score": det_score,
            })
        return results

    @staticmethod
    def cosine_similarity(vec1, vec2):
        v1 = np.array(vec1, dtype=np.float32)
        v2 = np.array(vec2, dtype=np.float32)
        norm1 = np.linalg.norm(v1)
        norm2 = np.linalg.norm(v2)
        if norm1 == 0 or norm2 == 0:
            return 0.0
        return float(np.dot(v1, v2) / (norm1 * norm2))

    @classmethod
    def match_face(cls, target_embedding, threshold=None):
        """Matches target 512D embedding against stored database face embeddings."""
        if threshold is None:
            threshold = getattr(settings, "FACE_MATCH_THRESHOLD", 0.45)

        stored_records = FaceEmbedding.objects.filter(is_active=True).select_related("user")
        if not stored_records.exists():
            raise FaceNotMatchedError("No registered face database found.")

        best_user = None
        best_score = -1.0

        for record in stored_records:
            sim = cls.cosine_similarity(target_embedding, record.embedding)
            if sim > best_score:
                best_score = sim
                best_user = record.user

        if best_score >= threshold and best_user is not None:
            return best_user, round(best_score, 4)

        raise FaceNotMatchedError(
            f"Face not recognized. Highest match score {best_score:.4f} below threshold {threshold}."
        )
