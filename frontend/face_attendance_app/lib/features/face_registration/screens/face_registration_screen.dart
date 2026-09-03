import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/api_client.dart';

/// Automatic face enrollment — runs ONLY after a student has been registered.
///
/// Flow (no manual "enroll" button):
///   1. A SMALL in-app camera window opens.
///   2. Exactly 5 face images are captured automatically.
///   3. Progress is shown as "Image 1/5" ... "Image 5/5".
///   4. Images are uploaded; the backend generates the face encoding.
///   5. The camera closes and "Registration Completed Successfully" is shown.
class FaceRegistrationScreen extends ConsumerStatefulWidget {
  final int targetUserId;
  final String studentName;

  const FaceRegistrationScreen({
    super.key,
    required this.targetUserId,
    this.studentName = 'Student',
  });

  @override
  ConsumerState<FaceRegistrationScreen> createState() =>
      _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends ConsumerState<FaceRegistrationScreen> {
  static const int requiredPhotos = 5;

  CameraController? _controller;
  bool _cameraReady = false;
  bool _capturing = false;
  bool _uploading = false;
  bool _completed = false;
  int _capturedCount = 0;
  final List<XFile> _capturedImages = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() => _error = 'Camera permission is required for face enrollment.');
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera available on this device.');
        return;
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      setState(() => _cameraReady = true);

      // Start the automatic 5-photo capture sequence.
      _startAutoCapture();
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to open camera: $e');
    }
  }

  Future<void> _startAutoCapture() async {
    if (_capturing || _capturedImages.length >= requiredPhotos) return;
    setState(() {
      _capturing = true;
      _error = null;
    });

    try {
      for (var i = _capturedImages.length; i < requiredPhotos; i++) {
        if (!mounted || _controller == null || !_controller!.value.isInitialized) {
          break;
        }
        final XFile photo = await _controller!.takePicture();
        _capturedImages.add(photo);
        if (mounted) {
          setState(() => _capturedCount = _capturedImages.length);
        }
        // Small pause between shots so the subject can adjust.
        if (_capturedImages.length < requiredPhotos) {
          await Future<void>.delayed(const Duration(milliseconds: 1200));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Capture failed: $e');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }

    if (_capturedImages.length >= requiredPhotos) {
      await _submitFaceRegistration();
    }
  }

  Future<void> _submitFaceRegistration() async {
    if (_uploading || _completed) return;
    setState(() => _uploading = true);

    try {
      final apiClient = await ApiClient.fromPrefs();
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
      final registered =
          response.data?['data']?['registered_count'] ?? requiredPhotos;

      // Close the camera now that enrollment is complete.
      await _disposeCamera();

      if (mounted) {
        setState(() => _completed = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$registered face images registered for ${widget.studentName}.'),
          backgroundColor: Colors.green,
        ));
        context.go('/dashboard');
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.message)
          : e.message;
      if (mounted) setState(() => _error = 'Enrollment failed: $msg');
    } catch (e) {
      if (mounted) setState(() => _error = 'Enrollment failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = _capturedCount;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Face Enrollment'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'Face Enrollment for ${widget.studentName}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _completed
                    ? 'Registration Completed Successfully'
                    : 'Keep your face inside the oval guide. Photos are captured automatically.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),

              // LARGE in-app camera window (~80% of the screen) with an
              // oval face guide. No capture button — photos are taken
              // automatically.
              Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 4, horizontal: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_cameraReady && _controller != null)
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width:
                                    _controller!.value.previewSize!.height,
                                height:
                                    _controller!.value.previewSize!.width,
                                child: CameraPreview(_controller!),
                              ),
                            )
                          else
                            Container(
                              color: Colors.black,
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white),
                              ),
                            ),
                          // Oval face guide.
                          CustomPaint(
                            painter: _OvalGuidePainter(
                              color: _capturing
                                  ? Colors.greenAccent
                                  : Colors.white,
                            ),
                          ),
                          if (_uploading)
                            Container(
                              color: Colors.black54,
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                        color: Colors.white),
                                    SizedBox(height: 12),
                                    Text(
                                      'Generating face encoding and saving…',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Progress: Image 1/5 .. Image 5/5
              Text(
                'Image $count/$requiredPhotos',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(requiredPhotos, (i) {
                  final done = i < count;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32,
                    height: 32,
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
                          : Text(
                              '${i + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),

              if (!_completed && _capturing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Capturing…',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OvalGuidePainter extends CustomPainter {
  final Color color;
  _OvalGuidePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.55,
      height: size.height * 0.7,
    );
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _OvalGuidePainter oldDelegate) =>
      oldDelegate.color != color;
}
