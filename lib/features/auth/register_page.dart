import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_profile.dart';
import '../../core/providers/auth_controller.dart';
import '../../core/providers/auth_controller.dart' show authRepositoryProvider;
import '../../core/app_dialogs.dart'; // Import global dialog helper

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _username = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _tower = TextEditingController();
  final _room = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String _getErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'This email is already registered. Please sign in instead.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'operation-not-allowed':
          return 'Registration is not allowed. Please contact support.';
        default:
          return error.message ?? 'Registration failed.';
      }
    } else if (error is Exception) {
      // Handle generic Exception messages
      final errorStr = error.toString();
      // Remove "Exception: " prefix if present
      String message = errorStr.replaceFirst(RegExp(r'^Exception:\s*'), '');
      
      // Check for specific error patterns
      if (message.toLowerCase().contains('email already exists') ||
          message.toLowerCase().contains('email already registered') ||
          message.toLowerCase().contains('account with this email')) {
        return 'This email is already registered. Please sign in instead.';
      }
      
      return message.isEmpty ? 'Registration failed.' : message;
    } else {
      // For any other error type
      final errorStr = error.toString();
      if (errorStr.toLowerCase().contains('email already exists') ||
          errorStr.toLowerCase().contains('email already registered') ||
          errorStr.toLowerCase().contains('account with this email')) {
        return 'This email is already registered. Please sign in instead.';
      }
      return errorStr.isEmpty ? 'Registration failed.' : errorStr;
    }
  }

  // Keep this for local UI-only dialogs (immediate, no async)
  // For auth/network errors after await, use showGlobalDialog() instead
  void _showDialog({required String title, required String message}) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Create Account'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
              'Create Account',
              style: theme.textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Fill in all fields to create your account',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Email *',
                hintText: 'student@example.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _password,
              obscureText: _obscurePassword,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: 'Password *',
                hintText: 'Minimum 6 characters',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmPassword,
              obscureText: _obscureConfirm,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: 'Confirm Password *',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _username,
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Username *',
                prefixIcon: Icon(Icons.person_outlined),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _first,
                    style: theme.textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _last,
                    style: theme.textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      labelText: 'Last Name *',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tower,
                    style: theme.textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      labelText: 'Tower Number *',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _room,
                    style: theme.textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      labelText: 'Room Number *',
                      prefixIcon: Icon(Icons.door_front_door_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                onPressed: auth.loading
                    ? null
                    : () async {
                        // Capture context BEFORE async operations to avoid unmounted widget error
                        final currentContext = context;
                        
                        // Validation
                        if (_email.text.trim().isEmpty ||
                            _password.text.isEmpty ||
                            _username.text.trim().isEmpty ||
                            _first.text.trim().isEmpty ||
                            _last.text.trim().isEmpty ||
                            _phone.text.trim().isEmpty ||
                            _tower.text.trim().isEmpty ||
                            _room.text.trim().isEmpty) {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            SnackBar(
                              content: const Text('Please fill in all required fields'),
                              backgroundColor: colorScheme.error,
                            ),
                          );
                          return;
                        }

                        if (!_email.text.trim().contains('@')) {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            SnackBar(
                              content: const Text('Please enter a valid email address'),
                              backgroundColor: colorScheme.error,
                            ),
                          );
                          return;
                        }

                        if (_password.text != _confirmPassword.text) {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            SnackBar(
                              content: const Text('Passwords do not match'),
                              backgroundColor: colorScheme.error,
                            ),
                          );
                          return;
                        }

                        if (_password.text.length < 6) {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            SnackBar(
                              content: const Text('Password must be at least 6 characters'),
                              backgroundColor: colorScheme.error,
                            ),
                          );
                          return;
                        }

                        try {
                          await ref.read(authControllerProvider.notifier).register(
                                email: _email.text.trim(),
                                password: _password.text,
                                username: _username.text.trim(),
                                firstName: _first.text.trim(),
                                lastName: _last.text.trim(),
                                phoneNumber: _phone.text.trim(),
                                towerNumber: _tower.text.trim(),
                                roomNumber: _room.text.trim(),
                                role: UserRole.resident, // Only students/residents can register
                              );

                          // ✅ If we reach here, registration succeeded
                          debugPrint('🟢 REGISTER SUCCESS');
                          if (!mounted) return;

                          // Wait for profile to load
                          UserProfile? profile;
                          for (int i = 0; i < 10; i++) {
                            await Future.delayed(const Duration(milliseconds: 200));
                            if (!mounted) return;
                            
                            final authState = ref.read(authControllerProvider);
                            
                            if (authState.profile != null) {
                              profile = authState.profile;
                              break;
                            }
                          }

                          if (!mounted) return;

                          if (profile != null) {
                            // Show email verification dialog
                            _showEmailVerificationDialog(currentContext, _email.text.trim());
                            
                            // Delay navigation until after dialog is shown
                            Future.delayed(const Duration(seconds: 1), () {
                              if (mounted) {
                                context.go('/home');
                              }
                            });
                          } else {
                            // Profile not loaded, but registration might have succeeded
                            // Show success and redirect to login (user can login manually)
                            _showEmailVerificationDialog(currentContext, _email.text.trim());
                            Future.delayed(const Duration(seconds: 1), () {
                              if (mounted) {
                                context.go('/login');
                              }
                            });
                          }
                        } on FirebaseAuthException catch (e) {
                          debugPrint('🔴 ERROR CAUGHT IN UI: ${e.code} - ${e.message}');

                          String message;
                          if (e.code == 'email-already-in-use') {
                            message = 'The email address is already in use by another account.';
                          } else {
                            message = e.message ?? 'Registration failed.';
                          }

                          // Use global dialog - works even if widget is unmounted
                          showGlobalDialog(
                            title: 'Registration Failed',
                            message: message,
                          );
                        } catch (e) {
                          debugPrint('🔴 GENERIC ERROR CAUGHT IN UI: $e');
                          
                          final message = _getErrorMessage(e);
                          // Use global dialog - works even if widget is unmounted
                          showGlobalDialog(
                            title: 'Registration Failed',
                            message: message,
                          );
                        }
                      },
                child: auth.loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                        ),
                      )
                    : Text(
                        'Create Account',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimary,
                        ),
                      ),
              ),
            ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEmailVerificationDialog(BuildContext context, String email) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const tealColor = Color(0xFF00857A);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tealColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: tealColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Check Your Email',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '✅ Account created successfully!',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF06D6A0),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We\'ve sent a verification email to:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tealColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please check your email and click the verification link to activate your account.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Note: The email may take a few minutes to arrive. Please check your spam folder if you don\'t see it.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Try to resend verification email
                try {
                  final authRepo = ref.read(authRepositoryProvider);
                  await authRepo.resendEmailVerification();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('✅ Verification email resent! Please check your inbox.'),
                        backgroundColor: const Color(0xFF06D6A0),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⚠️ Could not resend email. Please try logging in and use "Resend Verification" from your account.'),
                        backgroundColor: colorScheme.error,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Resend Email',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: tealColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Got it!',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _username.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _tower.dispose();
    _room.dispose();
    super.dispose();
  }
}

