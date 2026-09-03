import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/api_client.dart';

/// Live attendance screen.
///
/// The camera occupies ~80% of the screen, an oval face guide is drawn over
/// the preview and the app continuously detects faces and captures frames
/// automatically. Each frame is sent to the backend for face recognition:
///   matched   -> student/teacher details + "Attendance Marked Successfully"
///   unmatched -> "Unknown Person" (never "Invalid Face" — see README)
class LiveAttendanceScreen extends ConsumerStatefulWidget {
  const LiveAttendanceScreen({super.key});

  @override
  ConsumerState<LiveAttendanceScreen> createState() =>
      _LiveAttendanceScreenState();
}

enum _ScanState { idle, scanning, matched, unknown }

class _LiveAttendanceScreenState
    extends ConsumerState<LiveAttendanceScreen> {
  CameraController? _controller;
  bool _cameraReady = false;
  bool _uploading = false;
  Timer? _scanTimer;
  _ScanState _scanState = _ScanState.idle;
  String? _error;
  String _statusText = 'Look into the camera — attendance is automatic';
  Map<String, dynamic>? _result;

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
          setState(() => _error = 'Camera permission is required.');
        }
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera available.');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      if (mounted) setState(() => _cameraReady = true);
      _startScanLoop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to open camera: $e');
    }
  }

  /// Continuously capture + recognise every few seconds while no dialog is
  /// open. This is the "capture automatically" requirement.
  void _startScanLoop() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _uploading || _scanState == _ScanState.scanning) {
        return;
      }
      await _captureAndRecognise();
    });
  }

  Future<void> _captureAndRecognise() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _uploading) {
      return;
    }
    if (mounted) {
      setState(() {
        _uploading = true;
        _scanState = _ScanState.scanning;
      });
    }

    XFile? frame;
    try {
      frame = await controller.takePicture();
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanState = _ScanState.idle;
          _statusText = 'Capture failed — retrying…';
        });
      }
      return;
    }

    try {
      final apiClient = await ApiClient.fromPrefs();
      final formData = FormData.fromMap({
        // session_id is optional — the backend auto-resolves/creates today's
        // session for the matched student's class & section.
        'image': await MultipartFile.fromFile(
          frame.path,
          filename: 'live_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await apiClient.dio.post(
        'attendance/mark/',
        data: formData,
        options: Options(validateStatus: (code) => code != null && code < 500),
      );

      final body = response.data;
      final success = body is Map && body['success'] == true;

      if (success) {
        final data = (body['data'] ?? {}) as Map;
        if (mounted) {
          setState(() {
            _scanState = _ScanState.matched;
            _statusText = 'Attendance marked';
            _result = Map<String, dynamic>.from(data);
          });
        }
      } else {
        // Not matched (unknown face) — show Unknown Person, keep scanning.
        final message = body is Map ? (body['message'] ?? '') : '';
        if (mounted) {
          setState(() {
            _scanState = _ScanState.unknown;
            _statusText = 'Unknown person';
            _result = null;
          });
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _scanState = _ScanState.idle;
          _statusText = e.type == DioExceptionType.connectionError
              ? 'Cannot reach server — check the connection'
              : 'Recognition error — retrying…';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _scanState = _ScanState.idle);
    } finally {
      // Remove temp frame to avoid storage growth.
      try {
        await File(frame.path).delete();
      } catch (_) {}
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _showMatchedDialog({
    required String name,
    required String rollNumber,
    required String className,
    required String section,
    required String confidence,
    required String time,
  }) {
    final theme = Theme.of(context);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFF0FDF4),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration:
              const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline,
              color: Colors.white, size: 48),
        ),
        title: const Text(
          'Attendance Marked Successfully',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.green, fontWeight: FontWeight.bold, fontSize: 19),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: Colors.green,
              child: Icon(Icons.person, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87)),
            if (rollNumber.isNotEmpty)
              Text('Roll Number: $rollNumber',
                  style: const TextStyle(
                      color: Colors.black54, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Class: $className${section.isNotEmpty ? ' | $section' : ''}',
                style: const TextStyle(color: Colors.black87)),
            Text('Time: $time'
                '${confidence.isNotEmpty ? '  •  Match: ${confidence}' : ''}',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.green, borderRadius: BorderRadius.circular(20)),
              child: const Text('STATUS: PRESENT',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK',
                style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showUnknownDialog(String detail) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFFEF2F2),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration:
              const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: const Icon(Icons.gpp_bad, color: Colors.white, size: 48),
        ),
        title: const Text(
          'Unknown Person',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.red, fontWeight: FontWeight.bold, fontSize: 19),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Face Not Matched',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.redAccent)),
            const SizedBox(height: 8),
            Text(
              detail.isNotEmpty
                  ? detail
                  : 'This face does not match any registered student or teacher.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CONTINUE SCANNING',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Face Recognition Attendance')),
      body: SafeArea(
        child: Column(
          children: [
            // ~80% live camera with oval guide.
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_cameraReady && _controller != null)
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.previewSize!.height,
                            height: _controller!.value.previewSize!.width,
                            child: CameraPreview(_controller!),
                          ),
                        )
                      else
                        Container(
                          color: Colors.black,
                          child: Center(
                            child: _error != null
                                ? Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white),
                                    ),
                                  )
                                : const CircularProgressIndicator(
                                    color: Colors.white),
                          ),
                        ),

                      // Oval face guide.
                      if (_error == null)
                        CustomPaint(
                          painter: _LiveOvalGuidePainter(
                            color: switch (_scanState) {
                              _ScanState.matched => Colors.greenAccent,
                              _ScanState.unknown => Colors.redAccent,
                              _ => Colors.white,
                            },
                          ),
                        ),

                      if (_scanState == _ScanState.scanning)
                        const Positioned(
                          top: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Result panel stays visible below the camera; no recognition dialog
            // takes the user away from the live preview.
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: _LiveResultPanel(
                  state: _scanState, result: _result, statusText: _statusText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveResultPanel extends StatelessWidget {
  const _LiveResultPanel({required this.state, required this.result, required this.statusText});
  final _ScanState state;
  final Map<String, dynamic>? result;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    if (state == _ScanState.unknown) {
      return _card(Colors.red.shade50, Colors.red, const [
        Icon(Icons.person_off, color: Colors.red), SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Unknown Person', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          Text('No matching face found.'),
        ]),
      ]);
    }
    if (state != _ScanState.matched || result == null) {
      return _card(Theme.of(context).colorScheme.surfaceContainerHighest, Theme.of(context).colorScheme.primary, [
        Icon(Icons.face_retouching_natural, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text(statusText)),
      ]);
    }
    final isTeacher = result!['person_type'] == 'teacher';
    final photo = result!['photo']?.toString();
    final confidence = ((result!['confidence_score'] as num?)?.toDouble() ?? 0) * 100;
    final details = isTeacher
        ? ['Employee ID: ${result!['employee_id'] ?? '-'}', 'Subject: ${result!['subject'] ?? '-'}', 'Department: ${result!['department'] ?? '-'}']
        : ['Roll Number: ${result!['roll_number'] ?? '-'}', 'Class: ${result!['class_name'] ?? '-'} | Section: ${result!['section_name'] ?? '-'}', "Father's Name: ${result!['father_name'] ?? '-'}"];
    return _card(Colors.green.shade50, Colors.green, [
      CircleAvatar(radius: 26, backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null, child: photo == null || photo.isEmpty ? const Icon(Icons.person) : null),
      const SizedBox(width: 10),
      Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(result!['full_name']?.toString() ?? result!['student_name']?.toString() ?? 'Recognised person', style: const TextStyle(fontWeight: FontWeight.bold)),
        ...details.map((detail) => Text(detail, style: const TextStyle(fontSize: 12))),
        Text('Status: Present • Confidence: ${confidence.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text(DateTime.now().toLocal().toString().split('.').first, style: const TextStyle(fontSize: 11)),
      ]))),
    ]);
  }

  Widget _card(Color background, Color border, List<Widget> children) => Card(
    margin: EdgeInsets.zero, color: background,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: border)),
    child: Padding(padding: const EdgeInsets.all(10), child: Row(children: children)),
  );
}

class _LiveOvalGuidePainter extends CustomPainter {
  final Color color;
  _LiveOvalGuidePainter({required this.color});

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
  bool shouldRepaint(covariant _LiveOvalGuidePainter oldDelegate) =>
      oldDelegate.color != color;
}
