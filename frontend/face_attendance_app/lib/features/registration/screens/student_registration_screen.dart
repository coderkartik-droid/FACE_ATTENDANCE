import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../dashboard/screens/admin_dashboard_screen.dart';

class StudentRegistrationScreen extends ConsumerStatefulWidget {
  const StudentRegistrationScreen({super.key});

  @override
  ConsumerState<StudentRegistrationScreen> createState() => _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends ConsumerState<StudentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _admissionNumberController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  String _selectedGender = 'male';

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _sections = [];
  int? _selectedClassId;
  int? _selectedSectionId;
  bool _loadingOptions = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _loadingOptions = true);
    try {
      final apiClient = await ApiClient.fromPrefs();
      final resp = await apiClient.dio.get('academics/classes-list/');
      final data = resp.data;
      final raw = (data is Map ? data['data'] : data) ?? data;
      final list = (raw is List) ? raw.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
      if (mounted) setState(() => _classes = list);
    } catch (_) {
      // Leave classes empty; dropdown will simply have no options.
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<void> _loadSections(int classId) async {
    try {
      final apiClient = await ApiClient.fromPrefs();
      final resp = await apiClient.dio.get('academics/sections-list/');
      final data = resp.data;
      final raw = (data is Map ? data['data'] : data) ?? data;
      final list = (raw is List) ? raw.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
      final filtered = list.where((s) {
        final sectionClassId = s['class_obj'] ?? s['class'] ?? s['class_obj_id'];
        return int.tryParse(sectionClassId.toString()) == classId;
      }).toList();
      if (mounted) {
        setState(() {
          _sections = filtered;
          _selectedSectionId = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sections = [];
          _selectedSectionId = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _rollNumberController.dispose();
    _admissionNumberController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final apiClient = await ApiClient.fromPrefs();
      final response = await apiClient.dio.post(
        'auth/register/student/',
        data: {
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
          'email': _emailController.text.trim(),
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'father_name': _fatherNameController.text.trim(),
          'mother_name': _motherNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'roll_number': _rollNumberController.text.trim(),
          'admission_number': _admissionNumberController.text.trim(),
          'class_id': _selectedClassId,
          'section_id': _selectedSectionId,
          'gender': _selectedGender,
          'guardian_name': _guardianNameController.text.trim(),
          'guardian_phone': _guardianPhoneController.text.trim(),
          'address': _addressController.text.trim(),
        },
      );

      final newStudentId = (response.data['data']['id'] ?? 0) as int;
      ref.read(managementRefreshProvider.notifier).state++;
      final studentName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration Successful! Capturing face photos now…'),
            backgroundColor: Colors.green,
          ),
        );

        // The camera opens ONLY here — after a successful registration.
        context.pushReplacement(
          '/face-registration',
          extra: {'userId': newStudentId, 'studentName': studentName},
        );
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (e.message ?? 'Registration failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $message'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Registration Form')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter Student Profile Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              const Text('Face photos are captured automatically right after registration.'),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name', prefixIcon: Icon(Icons.person)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        prefixIcon: Icon(Icons.school),
                      ),
                      hint: _loadingOptions
                          ? const Text('Loading…')
                          : const Text('Select class'),
                      items: _classes
                          .map((c) => DropdownMenuItem<int>(
                                value: (c['id'] as num).toInt(),
                                child: Text(c['name'].toString()),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _selectedClassId = v);
                        if (v != null) _loadSections(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedSectionId,
                      decoration: const InputDecoration(
                        labelText: 'Section',
                        prefixIcon: Icon(Icons.group),
                      ),
                      hint: _selectedClassId == null
                          ? const Text('Select class first')
                          : const Text('Select section'),
                      items: _sections
                          .map((s) => DropdownMenuItem<int>(
                                value: (s['id'] as num).toInt(),
                                child: Text('Section ${s['name']}'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSectionId = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fatherNameController,
                      decoration: const InputDecoration(labelText: "Father's Name"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _motherNameController,
                      decoration: const InputDecoration(labelText: "Mother's Name"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rollNumberController,
                      decoration: const InputDecoration(labelText: 'Roll Number *', prefixIcon: Icon(Icons.badge)),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _admissionNumberController,
                      decoration: const InputDecoration(labelText: 'Admission No.', prefixIcon: Icon(Icons.confirmation_number)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username *', prefixIcon: Icon(Icons.account_box)),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email)),
                validator: (v) => v != null && v.isNotEmpty && !v.contains('@') ? 'Invalid email' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                validator: (v) => v == null || v.length < 8 ? 'Minimum 8 chars' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc)),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _selectedGender = v!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Student Phone', prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _guardianNameController,
                      decoration: const InputDecoration(labelText: 'Guardian Name'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _guardianPhoneController,
                      decoration: const InputDecoration(labelText: 'Guardian Phone'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.home)),
              ),
              const SizedBox(height: 28),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitRegistration,
                icon: const Icon(Icons.save),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register Student', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
