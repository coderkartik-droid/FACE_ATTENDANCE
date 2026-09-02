import logging
from rest_framework import generics, status, viewsets
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.contrib.auth import get_user_model

from core.mixins import StandardResponseMixin
from core.permissions import IsAdminOrTeacher, IsSchoolAdmin
from core.exceptions import BusinessValidationError, FaceNotDetectedError
from apps.faces.models import FaceEmbedding, FaceImage
from apps.faces.serializers import (
    FaceEmbeddingSerializer,
    FaceRegisterRequestSerializer,
    FaceVerifyRequestSerializer,
)
from apps.faces.services import FaceRecognitionService
from apps.accounts.serializers import UserSerializer

logger = logging.getLogger(__name__)
User = get_user_model()


class RegisterFaceView(generics.CreateAPIView):
    permission_classes = [IsSchoolAdmin]
    serializer_class = FaceRegisterRequestSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user_id = serializer.validated_data["user_id"]
        replace_existing = serializer.validated_data.get("replace_existing", True)

        try:
            target_user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            logger.warning(f"Face registration failed: User ID {user_id} not found.")
            raise BusinessValidationError("Target user not found.")

        # Face enrollment is supported for both students and teachers.
        if not (target_user.is_student() or target_user.is_teacher()):
            raise BusinessValidationError(
                "Face enrollment can only be performed for a student or teacher."
            )

        if replace_existing:
            deactivated_count = FaceEmbedding.objects.filter(
                user=target_user, is_active=True
            ).update(is_active=False)
            logger.info(f"Deactivated {deactivated_count} older face embeddings for user {target_user.username}.")

        images = serializer.validated_data["images"]
        created_embeddings = []

        for img in images:
            face_results = FaceRecognitionService.extract_face_embeddings(img)
            best_face = max(face_results, key=lambda x: x["score"])

            FaceImage.objects.create(user=target_user, image=img)

            embedding_record = FaceEmbedding.objects.create(
                user=target_user,
                embedding=best_face["embedding"],
                quality_score=best_face["score"],
                is_active=True,
            )
            created_embeddings.append(embedding_record)

        if hasattr(target_user, "student_profile"):
            target_user.student_profile.is_registration_complete = True
            target_user.student_profile.save()
        elif hasattr(target_user, "teacher_profile"):
            target_user.teacher_profile.is_registration_complete = True
            target_user.teacher_profile.save()

        logger.info(
            f"Successfully registered {len(created_embeddings)} face embeddings for user {target_user.username} (ID: {target_user.id}). Registration Complete."
        )

        return Response(
            {
                "success": True,
                "message": f"Successfully registered {len(created_embeddings)} face embedding(s) for {target_user.full_name}.",
                "data": {
                    "user_id": target_user.id,
                    "registered_count": len(created_embeddings),
                    "is_registration_complete": True,
                },
            },
            status=status.HTTP_201_CREATED,
        )


class VerifyFaceView(generics.CreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = FaceVerifyRequestSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        image_file = serializer.validated_data["image"]
        face_results = FaceRecognitionService.extract_face_embeddings(image_file)
        if not face_results:
            raise FaceNotDetectedError()
        best_face = max(face_results, key=lambda x: x["score"])

        matched_user, confidence = FaceRecognitionService.match_face(
            best_face["embedding"]
        )

        logger.info(f"Face verified: Matched user {matched_user.username} with confidence {confidence}.")

        return Response(
            {
                "success": True,
                "message": "Face verified successfully.",
                "data": {
                    "matched": True,
                    "user": UserSerializer(matched_user).data,
                    "confidence_score": confidence,
                },
            }
        )


class FaceEmbeddingViewSet(StandardResponseMixin, viewsets.ModelViewSet):
    permission_classes = [IsAdminOrTeacher]
    serializer_class = FaceEmbeddingSerializer
    queryset = FaceEmbedding.objects.select_related("user").all()
    filterset_fields = ["user", "is_active"]
