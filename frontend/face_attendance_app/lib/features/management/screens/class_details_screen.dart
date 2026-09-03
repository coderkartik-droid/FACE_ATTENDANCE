import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../dashboard/screens/admin_dashboard_screen.dart';

class ClassDetailsScreen extends ConsumerStatefulWidget {
  const ClassDetailsScreen({super.key, required this.classId, required this.className});
  final int classId;
  final String className;

  @override
  ConsumerState<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends ConsumerState<ClassDetailsScreen> {
  List<Map<String, dynamic>> _students = [];
  Set<int> _todayAttendanceIds = {};
  bool _loading = true;
  String? _error;
  late final int _classId;
  late final String _className;

  @override
  void initState() {
    super.initState();
    _classId = widget.classId;
    _className = widget.className;
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _loading = true);
    try {
      final apiClient = await ApiClient.fromPrefs();
      final selectedDate = ref.read(dashboardDateFilterProvider);
      final dates = dashboardDateRange(selectedDate);
      final response = await apiClient.dio.get('auth/students/', queryParameters: {'class_id': _classId}, options: Options(extra: {'skipCache': true}));
      final data = response.data is Map ? response.data['data'] : response.data;
      if (data is List) {
        final attendanceResponse = await apiClient.dio.get('attendance/today/', queryParameters: {
          'class_id': _classId,
          'status': 'PRESENT',
          if (dates.length == 1) 'date': dates.first,
          if (dates.length == 2) 'start_date': dates.first,
          if (dates.length == 2) 'end_date': dates.last,
        }, options: Options(extra: {'skipCache': true}));
        final attendanceData = attendanceResponse.data is Map ? attendanceResponse.data['data'] : attendanceResponse.data;
        final attendanceIds = attendanceData is List
            ? attendanceData
                .whereType<Map>()
                .map((record) => (record['student'] as num?)?.toInt())
                .whereType<int>()
                .toSet()
            : <int>{};
        setState(() {
          _students = List<Map<String, dynamic>>.from(data);
          _todayAttendanceIds = attendanceIds;
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteStudent(int studentId, String studentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to delete $studentName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiClient = await ApiClient.fromPrefs();
        await apiClient.dio.delete('auth/students/$studentId/');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student deleted successfully'), backgroundColor: Colors.green),
          );
          _loadStudents();
          ref.invalidate(dashboardSummaryProvider);
          ref.read(managementRefreshProvider.notifier).state++;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete student: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _editStudent(Map<String, dynamic> student) async {
    final user = student['user'] as Map<String, dynamic>? ?? {};
    final first = TextEditingController(text: user['first_name']?.toString() ?? '');
    final last = TextEditingController(text: user['last_name']?.toString() ?? '');
    final roll = TextEditingController(text: student['roll_number']?.toString() ?? '');
    final father = TextEditingController(text: student['father_name']?.toString() ?? '');
    final mother = TextEditingController(text: student['mother_name']?.toString() ?? '');
    final phone = TextEditingController(text: user['phone']?.toString() ?? '');
    final address = TextEditingController(text: student['address']?.toString() ?? '');
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Edit Student'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: first, decoration: const InputDecoration(labelText: 'First Name')), TextField(controller: last, decoration: const InputDecoration(labelText: 'Last Name')), TextField(controller: roll, decoration: const InputDecoration(labelText: 'Roll Number')), TextField(controller: father, decoration: const InputDecoration(labelText: "Father's Name")), TextField(controller: mother, decoration: const InputDecoration(labelText: "Mother's Name")), TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')), TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save'))]));
    if (saved != true) return;
    try {
      final apiClient = await ApiClient.fromPrefs();
      await apiClient.dio.patch('auth/students/${student['id']}/', data: {'first_name': first.text.trim(), 'last_name': last.text.trim(), 'roll_number': roll.text.trim(), 'father_name': father.text.trim(), 'mother_name': mother.text.trim(), 'phone': phone.text.trim(), 'address': address.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student updated successfully'), backgroundColor: Colors.green));
      await _loadStudents();
      ref.invalidate(dashboardSummaryProvider);
      ref.read(managementRefreshProvider.notifier).state++;
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update student: $e'), backgroundColor: Colors.red)); }
    finally { first.dispose(); last.dispose(); roll.dispose(); father.dispose(); mother.dispose(); phone.dispose(); address.dispose(); }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(dashboardDateFilterProvider, (previous, next) {
      if (previous != next) _loadStudents();
    });
    ref.listen<int>(managementRefreshProvider, (previous, next) {
      if (previous != null && previous != next) _loadStudents();
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(_className),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _students.isEmpty
                  ? const Center(child: Text('No students in this class'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _students.length,
                      itemBuilder: (context, index) {
                        final student = _students[index];
                        final profile = student;
                        final user = student['user'] as Map<String, dynamic>? ?? {};
                        final photo = user['profile_picture']?.toString();
                        final hasFace = profile['is_registration_complete'] == true;
                        final isPresentToday = _todayAttendanceIds.contains(user['id']);
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: hasFace ? Colors.green : Colors.grey,
                                      backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                                      child: Icon(
                                        hasFace ? Icons.face : Icons.person,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user['full_name']?.toString() ?? 'Unknown',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Text('Roll: ${profile['roll_number']?.toString() ?? 'N/A'}'),
                                          Text('Father: ${profile['father_name']?.toString() ?? 'N/A'}'),
                                          Text('Section: ${profile['section_name']?.toString() ?? 'N/A'}'),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isPresentToday ? Colors.green : Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isPresentToday ? 'Present' : 'Absent',
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _editStudent(student),
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Edit'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => _deleteStudent(
                                        student['id'] as int,
                                        user['full_name']?.toString() ?? 'Student',
                                      ),
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Delete'),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
