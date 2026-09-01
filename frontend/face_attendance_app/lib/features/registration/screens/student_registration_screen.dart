import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';

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
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  String _selectedGender = 'male';
  bool _isLoading = false;

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final apiClient = ApiClient();
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
          'gender': _selectedGender,
          'guardian_name': _guardianNameController.text.trim(),
          'guardian_phone': _guardianPhoneController.text.trim(),
          'address': _addressController.text.trim(),
        },
      );

      final newStudentId = (response.data['data']['id'] ?? 0) as int;
      final studentName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student registered successfully! Starting face enrollment…'),
            backgroundColor: Colors.green,
          ),
        );

        // Camera opens ONLY here — after successful registration (Step 2).
        context.push('/face-registration',
            extra: {'userId': newStudentId, 'studentName': studentName});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error registering student: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 1: Student Registration Form')),
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
              const Text('Record will remain incomplete until Face Registration is finished in Step 2.'),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name *', prefixIcon: Icon(Icons.person)),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name *'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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

              TextFormField(
                controller: _rollNumberController,
                decoration: const InputDecoration(labelText: 'Roll Number / Student ID *', prefixIcon: Icon(Icons.badge)),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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
                decoration: const InputDecoration(labelText: 'Email Address *', prefixIcon: Icon(Icons.email)),
                validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password *', prefixIcon: Icon(Icons.lock)),
                validator: (v) => v == null || v.length < 6 ? 'Minimum 6 chars' : null,
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
