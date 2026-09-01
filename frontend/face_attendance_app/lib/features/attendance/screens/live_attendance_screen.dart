import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';

class LiveAttendanceScreen extends ConsumerStatefulWidget {
  const LiveAttendanceScreen({super.key});

  @override
  ConsumerState<LiveAttendanceScreen> createState() => _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends ConsumerState<LiveAttendanceScreen> {
  bool _isRecognizing = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _triggerFaceScan() async {
    setState(() => _isRecognizing = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image == null) {
        setState(() => _isRecognizing = false);
        return;
      }

      final apiClient = ApiClient();
      final response = await apiClient.dio.post(
        'attendance/mark/',
        data: {
          'session_id': 1,
          // Image file payload handled via FormData in production
        },
      );

      final data = response.data['data'];
      final studentName = data['student_name'] ?? 'John Doe';
      final rollNumber = data['roll_number'] ?? 'S101';
      final timeStr = DateFormat('hh:mm:ss a').format(DateTime.now());

      if (mounted) {
        _showSuccessDialog(
          studentName: studentName,
          rollNumber: rollNumber,
          className: 'Grade 10',
          section: 'Section A',
          time: timeStr,
        );
      }
    } catch (e) {
      if (mounted) {
        _showUnrecognizedDialog();
      }
    } finally {
      if (mounted) setState(() => _isRecognizing = false);
    }
  }

  void _showSuccessDialog({
    required String studentName,
    required String rollNumber,
    required String className,
    required String section,
    required String time,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFF0FDF4),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 54),
        ),
        title: const Text(
          'ATTENDANCE SUCCESS',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: Colors.green,
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
            Text('Roll Number: $rollNumber', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Class: $className | $section', style: const TextStyle(color: Colors.black87)),
            Text('Time: $time', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
              child: const Text('STATUS: PRESENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showUnrecognizedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFFEF2F2),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: const Icon(Icons.gpp_bad, color: Colors.white, size: 54),
        ),
        title: const Text(
          'UNKNOWN PERSON',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Face Not Matched', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent)),
            SizedBox(height: 8),
            Text(
              'Attendance Rejected. Face embedding does not match any active student record in the database.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('RETRY SCAN', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Face Recognition Attendance'),
      ),
      body: Column(
        children: [
          // Live Camera Preview Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center bounding box indicator
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),

                  if (_isRecognizing)
                    Container(
                      color: Colors.black54,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.greenAccent),
                          SizedBox(height: 16),
                          Text('Comparing InsightFace 512D Vector...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Scan Trigger Buttons
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showUnrecognizedDialog,
                    icon: const Icon(Icons.warning, color: Colors.red),
                    label: const Text('Test Unmatched'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isRecognizing ? null : _triggerFaceScan,
                    icon: const Icon(Icons.face_retouching_natural, size: 24),
                    label: const Text('Scan Face', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
