import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../dashboard/screens/admin_dashboard_screen.dart';

class TeachersScreen extends ConsumerStatefulWidget {
  const TeachersScreen({super.key});

  @override
  ConsumerState<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends ConsumerState<TeachersScreen> {
  List<Map<String, dynamic>> _teachers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _loading = true);
    try {
      final apiClient = await ApiClient.fromPrefs();
      final response = await apiClient.dio.get('auth/teachers/', options: Options(extra: {'skipCache': true}));
      final data = response.data is Map ? response.data['data'] : response.data;
      if (data is List) {
        setState(() => _teachers = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteTeacher(int teacherId, String teacherName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Teacher'),
        content: Text('Are you sure you want to delete $teacherName?'),
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
        await apiClient.dio.delete('auth/teachers/$teacherId/');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teacher deleted successfully'), backgroundColor: Colors.green),
          );
          _loadTeachers();
          ref.invalidate(dashboardSummaryProvider);
          ref.read(managementRefreshProvider.notifier).state++;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete teacher: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _editTeacher(Map<String, dynamic> teacher) async {
    final user = teacher['user'] as Map<String, dynamic>? ?? {};
    final first = TextEditingController(text: user['first_name']?.toString() ?? '');
    final last = TextEditingController(text: user['last_name']?.toString() ?? '');
    final employee = TextEditingController(text: teacher['employee_id']?.toString() ?? '');
    final subject = TextEditingController(text: teacher['qualification']?.toString() ?? '');
    final department = TextEditingController(text: teacher['department']?.toString() ?? '');
    final phone = TextEditingController(text: user['phone']?.toString() ?? '');
    final email = TextEditingController(text: user['email']?.toString() ?? '');
    if (!mounted) return;
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Edit Teacher'), content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(children: [
      Row(children: [Expanded(child: TextField(controller: first, decoration: const InputDecoration(labelText: 'First Name'))), const SizedBox(width: 12), Expanded(child: TextField(controller: last, decoration: const InputDecoration(labelText: 'Last Name')))]),
      TextField(controller: employee, decoration: const InputDecoration(labelText: 'Employee ID')),
      TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
      TextField(controller: department, decoration: const InputDecoration(labelText: 'Department')),
      TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
      TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
    ]))), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save'))]));
    if (saved != true) return;
    try {
      final apiClient = await ApiClient.fromPrefs();
      await apiClient.dio.patch('auth/teachers/${teacher['id']}/', data: {'first_name': first.text.trim(), 'last_name': last.text.trim(), 'employee_id': employee.text.trim(), 'subject': subject.text.trim(), 'department': department.text.trim(), 'phone': phone.text.trim(), 'email': email.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teacher updated successfully'), backgroundColor: Colors.green));
      await _loadTeachers();
      ref.invalidate(dashboardSummaryProvider);
      ref.read(managementRefreshProvider.notifier).state++;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update teacher: $e'), backgroundColor: Colors.red));
    } finally { first.dispose(); last.dispose(); employee.dispose(); subject.dispose(); department.dispose(); phone.dispose(); email.dispose(); }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(managementRefreshProvider, (previous, next) {
      if (previous != null) _loadTeachers();
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teachers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeachers,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _teachers.isEmpty
                  ? const Center(child: Text('No teachers found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _teachers.length,
                      itemBuilder: (context, index) {
                        final teacher = _teachers[index];
                        final profile = teacher;
                        final user = teacher['user'] as Map<String, dynamic>? ?? {};
                        final photo = user['profile_picture']?.toString();
                        final hasFace = profile['is_registration_complete'] == true;
                        
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
                                          Text('Employee ID: ${profile['employee_id']?.toString() ?? 'N/A'}'),
                                          Text('Department: ${profile['department']?.toString() ?? 'N/A'}'),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: hasFace ? Colors.green : Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        hasFace ? 'Face Registered' : 'Face Pending',
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
                                      onPressed: () => _editTeacher(teacher),
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Edit'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => _deleteTeacher(
                                        teacher['id'] as int,
                                        user['full_name']?.toString() ?? 'Teacher',
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
