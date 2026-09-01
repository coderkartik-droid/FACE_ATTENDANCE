
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';

/// Step 2: Automatic face enrollment.
/// Opens ONLY after successful student registration. Never before.
/// Captures exactly 5 face photos, uploads them for embedding generation.
class FaceRegistrationScreen extends ConsumerStatefulWidget {
  final int targetUserId;
  final String studentName;

  const FaceRegistrationScreen({
    super.key,
    required this.targetUserId,
    this.studentName = 'Student',
  });

  @override
  ConsumerState<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends ConsumerState<FaceRegistrationScreen> {
  static const int requiredPhotos = 5;
  final List<XFile> _capturedImages = [];
  bool _isUploading = false;
  String? _error;
  final ImagePicker _picker = ImagePicker();

  Future<void> _captureNext() async {
    if (_capturedImages.length >= requiredPhotos || _isUploading) return;
    setState(() => _error = null);
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (photo == null) {
        if (!mounted) return;
        setState(() => _error = 'Capture cancelled. Please try again.');
        return;
      }
      setState(() => _capturedImages.add(photo));
      if (_capturedImages.length < requiredPhotos && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _captureNext());
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: $e');
    }
  }

  Future<void> _submitFaceRegistration() async {
    if (_capturedImages.length != requiredPhotos) return;

    setState(() => _isUploading = true);

    try {
      final apiClient = ApiClient();
      final formData = FormData();
      formData.fields.add(MapEntry('user_id', widget.targetUserId.toString()));
      formData.fields.add(MapEntry('replace_existing', 'true'));
      for (final img in _capturedImages) {
        formData.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(img.path, filename: img.name),
          ),
        );
      }
      final response = await apiClient.dio.post('faces/register/', data: formData);
      final registered = response.data['data']?['registered_count'] ?? requiredPhotos;

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 54),
            title: const Text('Face Enrollment Completed Successfully'),
            content: Text(
              '$registered face embedding(s) generated and saved for ${widget.studentName}. The student is now marked as Face Registered.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/dashboard');
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Upload failed';
      if (mounted) setState(() => _error = 'Enrollment failed: $msg');
    } catch (e) {
      if (mounted) setState(() => _error = 'Enrollment failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = _capturedImages.length;
    final complete = count >= requiredPhotos;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Step 2: Face Enrollment'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  complete ? Icons.face_retouching_natural : Icons.face,
                  size: 72,
                  color: complete ? Colors.green : theme.primaryColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'Face Enrollment for ${widget.studentName}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  complete
                      ? 'All photos captured. Upload to generate face embeddings.'
                      : 'Photo ${count + 1}/$requiredPhotos — position the face inside the oval and capture.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),

                // Progress indicator: Photo 1/5 .. Photo 5/5
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(requiredPhotos, (i) {
                    final done = i < count;
                    return Container(
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? Colors.green : Colors.black12,
                        border: Border.all(
                          color: done ? Colors.green : theme.primaryColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  'Photo $count/$requiredPhotos captured',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),

                if (_isUploading)
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Generating face embeddings and saving…'),
                    ],
                  )
                else ...[
                  ElevatedButton.icon(
                    onPressed: complete ? _submitFaceRegistration : _captureNext,
                    icon: Icon(complete ? Icons.cloud_upload : Icons.camera_alt),
                    label: Text(
                      complete
                          ? 'Save Face Data & Complete Enrollment'
                          : 'Capture Photo ${count + 1}/$requiredPhotos',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: complete ? Colors.green : theme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (count > 0 && !complete)
                    TextButton(
                      onPressed: () => setState(() => _capturedImages.removeLast()),
                      child: const Text('Retake last photo'),
                    ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'The camera is only used for face enrollment after successful registration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
