import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../dashboard/screens/admin_dashboard_screen.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _loading = true);
    try {
      final apiClient = await ApiClient.fromPrefs();
      final response = await apiClient.dio.get('auth/students/');
      final data = response.data is Map ? response.data['data'] : response.data;
      if (data is List) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(data);
          _filteredStudents = _students;
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _students;
      } else {
        _filteredStudents = _students.where((student) {
          final name = (student['user']?['full_name']?.toString() ?? '').toLowerCase();
          final roll = (student['roll_number']?.toString() ?? '').toLowerCase();
          return name.contains(query) || roll.contains(query);
        }).toList();
      }
      _currentPage = 1;
    });
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
    final admission = TextEditingController(text: student['admission_number']?.toString() ?? '');
    final father = TextEditingController(text: student['father_name']?.toString() ?? '');
    final mother = TextEditingController(text: student['mother_name']?.toString() ?? '');
    final phone = TextEditingController(text: user['phone']?.toString() ?? '');
    final address = TextEditingController(text: student['address']?.toString() ?? '');
    final apiClient = await ApiClient.fromPrefs();
    List<Map<String, dynamic>> classes = [];
    List<Map<String, dynamic>> sections = [];
    try {
      final classResponse = await apiClient.dio.get('academics/classes-list/', options: Options(extra: {'skipCache': true}));
      final classData = classResponse.data is Map ? classResponse.data['data'] : classResponse.data;
      classes = classData is List ? List<Map<String, dynamic>>.from(classData) : [];
      final sectionResponse = await apiClient.dio.get('academics/sections-list/', options: Options(extra: {'skipCache': true}));
      final sectionData = sectionResponse.data is Map ? sectionResponse.data['data'] : sectionResponse.data;
      sections = sectionData is List ? List<Map<String, dynamic>>.from(sectionData) : [];
    } catch (_) {}
    if (!mounted) return;
    int? classId = (student['class_obj'] as num?)?.toInt();
    int? sectionId = (student['section_obj'] as num?)?.toInt();
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Edit Student'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(children: [
          Row(children: [Expanded(child: TextField(controller: first, decoration: const InputDecoration(labelText: 'First Name'))), const SizedBox(width: 12), Expanded(child: TextField(controller: last, decoration: const InputDecoration(labelText: 'Last Name')))]),
          TextField(controller: roll, decoration: const InputDecoration(labelText: 'Roll Number')),
          TextField(controller: admission, decoration: const InputDecoration(labelText: 'Admission Number')),
          TextField(controller: father, decoration: const InputDecoration(labelText: "Father's Name")),
          TextField(controller: mother, decoration: const InputDecoration(labelText: "Mother's Name")),
          DropdownButtonFormField<int>(value: classId, decoration: const InputDecoration(labelText: 'Class'), items: classes.map((item) => DropdownMenuItem(value: (item['id'] as num).toInt(), child: Text(item['name'].toString()))).toList(), onChanged: (value) => setDialogState(() { classId = value; sectionId = null; })),
          DropdownButtonFormField<int>(value: sectionId, decoration: const InputDecoration(labelText: 'Section'), items: sections.where((item) {
            final sectionClassId = item['class_obj'] ?? item['class'] ?? item['class_obj_id'];
            return classId == null || int.tryParse(sectionClassId.toString()) == classId;
          }).map((item) => DropdownMenuItem(value: (item['id'] as num).toInt(), child: Text(item['name'].toString()))).toList(), onChanged: (value) => setDialogState(() => sectionId = value)),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save'))],
      ),
    ));
    if (saved != true) return;
    try {
      await apiClient.dio.patch('auth/students/${student['id']}/', data: {'first_name': first.text.trim(), 'last_name': last.text.trim(), 'roll_number': roll.text.trim(), 'admission_number': admission.text.trim(), 'father_name': father.text.trim(), 'mother_name': mother.text.trim(), 'class_id': classId, 'section_id': sectionId, 'phone': phone.text.trim(), 'address': address.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student updated successfully'), backgroundColor: Colors.green));
      await _loadStudents();
      ref.invalidate(dashboardSummaryProvider);
      ref.read(managementRefreshProvider.notifier).state++;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update student: $e'), backgroundColor: Colors.red));
    } finally { first.dispose(); last.dispose(); roll.dispose(); admission.dispose(); father.dispose(); mother.dispose(); phone.dispose(); address.dispose(); }
  }

  List<Map<String, dynamic>> get _paginatedStudents {
    final start = (_currentPage - 1) * _pageSize;
    final end = start + _pageSize;
    return _filteredStudents.sublist(start, end > _filteredStudents.length ? _filteredStudents.length : end);
  }

  int get _totalPages => (_filteredStudents.length / _pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(managementRefreshProvider, (previous, next) {
      if (previous != null) _loadStudents();
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or roll number',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _filteredStudents.isEmpty
                        ? const Center(child: Text('No students found'))
                        : Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _paginatedStudents.length,
                                  itemBuilder: (context, index) {
                                    final student = _paginatedStudents[index];
                                    final profile = student;
                                    final user = student['user'] as Map<String, dynamic>? ?? {};
                                    final photo = user['profile_picture']?.toString();
                                    final hasFace = profile['is_registration_complete'] == true;
                                    
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: hasFace ? Colors.green : Colors.grey,
                                          backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                                          child: Icon(
                                            hasFace ? Icons.face : Icons.person,
                                            color: Colors.white,
                                          ),
                                        ),
                                        title: Text(user['full_name']?.toString() ?? 'Unknown'),
                                        subtitle: Text('Roll: ${profile['roll_number']?.toString() ?? 'N/A'}'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
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
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              onPressed: () => _editStudent(student),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              color: Colors.red,
                                              onPressed: () => _deleteStudent(
                                                student['id'] as int,
                                                user['full_name']?.toString() ?? 'Student',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (_totalPages > 1)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left),
                                        onPressed: _currentPage > 1
                                            ? () => setState(() => _currentPage--)
                                            : null,
                                      ),
                                      Text('Page $_currentPage of $_totalPages'),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right),
                                        onPressed: _currentPage < _totalPages
                                            ? () => setState(() => _currentPage++)
                                            : null,
                                      ),
                                    ],
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
