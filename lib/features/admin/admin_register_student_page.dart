import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AdminRegisterStudentPage extends StatefulWidget {
  const AdminRegisterStudentPage({super.key});

  @override
  State<AdminRegisterStudentPage> createState() => _AdminRegisterStudentPageState();
}

class _AdminRegisterStudentPageState extends State<AdminRegisterStudentPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _matric = TextEditingController();
  final _room = TextEditingController();
  XFile? _photo;

  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _matric.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      setState(() => _photo = file);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Student info captured (not yet saved to backend)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF00857A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register New User'),
        backgroundColor: brand,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _photo != null ? FileImage(File(_photo!.path)) : null,
                          child: _photo == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_outlined, color: brand, size: 28),
                                    SizedBox(height: 4),
                                    Text('Tap to add photo', style: TextStyle(color: brand, fontSize: 12)),
                                  ],
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _pickPhoto,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: brand,
                          side: const BorderSide(color: brand),
                        ),
                        child: const Text('Select Photo'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _readOnlyField('User Type', 'Resident'),
                const SizedBox(height: 12),
                const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _inputField(
                  controller: _name,
                  label: 'Full Name',
                  icon: Icons.person,
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter full name' : null,
                ),
                _inputField(
                  controller: _phone,
                  label: 'Phone Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                const Text('Account Information', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _inputField(
                  controller: _matric,
                  label: 'Matric ID',
                  icon: Icons.badge_outlined,
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter matric id' : null,
                ),
                _inputField(
                  controller: _email,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter email' : null,
                ),
                _inputField(
                  controller: _room,
                  label: 'Room Number',
                  icon: Icons.meeting_room_outlined,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _submit,
                    child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(value, style: const TextStyle(color: Colors.black87)),
        ),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF00857A)),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF00857A)),
          ),
        ),
      ),
    );
  }
}


