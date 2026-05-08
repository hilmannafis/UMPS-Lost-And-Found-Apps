import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_profile.dart';
import '../../core/providers/auth_controller.dart';

class CreateAdminPage extends ConsumerStatefulWidget {
  const CreateAdminPage({super.key});

  @override
  ConsumerState<CreateAdminPage> createState() => _CreateAdminPageState();
}

class _CreateAdminPageState extends ConsumerState<CreateAdminPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _username = TextEditingController(text: 'admin');
  final _firstName = TextEditingController(text: 'Admin');
  final _lastName = TextEditingController(text: 'User');
  final _phone = TextEditingController(text: '1234567890');
  final _tower = TextEditingController(text: '1');
  final _room = TextEditingController(text: '1');
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Admin Account'),
        backgroundColor: const Color(0xFF00857A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Admin Account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fill in the details below to create an admin account in Firebase.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email *',
                hintText: 'admin@example.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password *',
                hintText: 'Minimum 6 characters',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPassword,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstName,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lastName,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tower,
                    decoration: const InputDecoration(
                      labelText: 'Tower Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _room,
                    decoration: const InputDecoration(
                      labelText: 'Room Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.door_front_door),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00857A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: auth.loading
                    ? null
                    : () async {
                        if (_email.text.trim().isEmpty || _password.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill in email and password'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (_password.text != _confirmPassword.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Passwords do not match'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (_password.text.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password must be at least 6 characters'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        try {
                          await ref.read(authControllerProvider.notifier).register(
                                email: _email.text.trim(),
                                password: _password.text,
                                username: _username.text.isEmpty ? 'admin' : _username.text,
                                firstName: _firstName.text.isEmpty ? 'Admin' : _firstName.text,
                                lastName: _lastName.text.isEmpty ? 'User' : _lastName.text,
                                phoneNumber: _phone.text.isEmpty ? '1234567890' : _phone.text,
                                towerNumber: _tower.text.isEmpty ? '1' : _tower.text,
                                roomNumber: _room.text.isEmpty ? '1' : _room.text,
                                role: UserRole.admin,
                              );

                          if (!mounted) return;

                          // Wait for profile to load (check multiple times)
                          UserProfile? profile;
                          for (int i = 0; i < 10; i++) {
                            await Future.delayed(const Duration(milliseconds: 200));
                            if (!mounted) return;
                            
                            final currentAuth = ref.read(authControllerProvider);
                            
                            if (currentAuth.error != null) {
                              String errorMessage = 'Registration failed';
                              
                              // Check if it's a FirebaseAuthException
                              if (currentAuth.error is FirebaseAuthException) {
                                final authError = currentAuth.error as FirebaseAuthException;
                                switch (authError.code) {
                                  case 'email-already-in-use':
                                    errorMessage = 'This email is already registered. Please use a different email.';
                                    break;
                                  case 'weak-password':
                                    errorMessage = 'Password is too weak. Please use a stronger password.';
                                    break;
                                  case 'invalid-email':
                                    errorMessage = 'Invalid email address. Please check your email format.';
                                    break;
                                  case 'operation-not-allowed':
                                    errorMessage = 'Registration is not allowed. Please contact support.';
                                    break;
                                  default:
                                    errorMessage = 'Registration failed: ${authError.message ?? authError.code}';
                                }
                              } else {
                                // For non-Firebase errors, use the error string
                                final errorStr = currentAuth.error.toString();
                                if (errorStr.contains('email-already-in-use')) {
                                  errorMessage = 'This email is already registered. Please use a different email.';
                                } else {
                                  errorMessage = errorStr;
                                }
                              }
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                              return;
                            }
                            
                            if (currentAuth.profile != null) {
                              profile = currentAuth.profile;
                              break;
                            }
                          }

                          if (!mounted) return;

                          if (profile != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Admin account created successfully! Redirecting...'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            // Redirect to admin dashboard
                            Future.delayed(const Duration(seconds: 1), () {
                              if (mounted) {
                                context.go('/admin');
                              }
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Admin account created! Please login with your credentials.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            String errorMessage = 'Registration failed';
                            
                            // Check if it's a FirebaseAuthException
                            if (e is FirebaseAuthException) {
                              switch (e.code) {
                                case 'email-already-in-use':
                                  errorMessage = 'This email is already registered. Please use a different email.';
                                  break;
                                case 'weak-password':
                                  errorMessage = 'Password is too weak. Please use a stronger password.';
                                  break;
                                case 'invalid-email':
                                  errorMessage = 'Invalid email address. Please check your email format.';
                                  break;
                                default:
                                  errorMessage = 'Registration failed: ${e.message ?? e.code}';
                              }
                            } else {
                              errorMessage = 'Registration error: $e';
                            }
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMessage),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      },
                child: auth.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Create Admin Account',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            if (auth.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        auth.error.toString(),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _username.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _tower.dispose();
    _room.dispose();
    super.dispose();
  }
}

