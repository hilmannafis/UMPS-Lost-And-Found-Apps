import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_controller.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/providers/auth_controller.dart' show authRepositoryProvider;
import '../../core/models/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

const _brand = Color(0xFF00857A);

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  bool _isEditMode = false;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _towerController;
  late TextEditingController _roomController;
  final _formKey = GlobalKey<FormState>();
  DateTime? _lastEmailSentTime;
  static const _emailCooldownDuration = Duration(minutes: 2);
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _towerController = TextEditingController();
    _roomController = TextEditingController();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _towerController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // This will rebuild the widget and update the button text
        });
        final now = DateTime.now();
        if (_lastEmailSentTime != null && 
            now.difference(_lastEmailSentTime!) >= _emailCooldownDuration) {
          timer.cancel();
        }
      }
    });
  }

  void _showPasswordChangeDialog({required bool success, String? errorMessage}) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: success ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(success ? "Password Updated" : "Update Failed"),
          ],
        ),
        content: Text(
          success
              ? "Your password was successfully updated!"
              : errorMessage ?? "Something went wrong. Please try again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _updateControllers(UserProfile? profile) {
    if (profile != null) {
      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
      _phoneController.text = profile.phoneNumber;
      _towerController.text = profile.towerNumber;
      _roomController.text = profile.roomNumber;
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        await ref.read(authControllerProvider.notifier).updateProfile(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          towerNumber: _towerController.text.trim(),
          roomNumber: _roomController.text.trim(),
        );
        
        setState(() {
          _isEditMode = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profile updated successfully!'),
              backgroundColor: Color(0xFF06D6A0),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Error: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _cancelEdit() {
    final profile = ref.read(authControllerProvider).profile;
    _updateControllers(profile);
    setState(() {
      _isEditMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final profile = auth.profile;
    
    // Initialize or update controllers when profile changes (but only if not in edit mode)
    if (profile != null && !_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isEditMode) {
          _updateControllers(profile);
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Account', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: _buildBottomNavBar(context, ref, 3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Profile Header Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _brand.withOpacity(0.3), width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: _brand.withOpacity(0.1),
                          child: Text(
                            (profile?.firstName.isNotEmpty == true ? profile!.firstName[0] : '?').toUpperCase(),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _brand),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile != null ? '${profile.firstName} ${profile.lastName}' : 'User',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _brand.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          profile?.role.name.toUpperCase() ?? 'RESIDENT',
                          style: const TextStyle(color: _brand, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _CardSection(
                title: 'Personal Information',
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Full Name - split into first and last name when editing
                      if (_isEditMode)
                        Row(
                          children: [
                            Expanded(
                              child: _EditableInfoField(
                                label: 'First Name',
                                controller: _firstNameController,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'First name is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _EditableInfoField(
                                label: 'Last Name',
                                controller: _lastNameController,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Last name is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        )
                      else
                        _InfoField(label: 'Full Name', value: profile != null ? '${profile.firstName} ${profile.lastName}' : ''),
                      _InfoField(label: 'Email', value: profile?.email ?? ''),
                      // Show Firebase Auth email if different from profile email
                      Builder(
                        builder: (context) {
                          final authUser = FirebaseAuth.instance.currentUser;
                          final authEmail = authUser?.email ?? '';
                          final profileEmail = profile?.email ?? '';
                          
                          if (authEmail.isNotEmpty && 
                              profileEmail.isNotEmpty && 
                              authEmail.toLowerCase() != profileEmail.toLowerCase()) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Email Mismatch Detected!',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'You are logged in as: $authEmail\n'
                                      'But your profile shows: $profileEmail\n\n'
                                      'Verification emails will be sent to: $authEmail\n\n'
                                      'To verify $profileEmail, please log out and log in with that account.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    // Email verification status
                    Builder(
                      builder: (context) {
                        final user = FirebaseAuth.instance.currentUser;
                        final isEmailVerified = user?.emailVerified ?? false;
                        if (!isEmailVerified && profile != null) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Email not verified',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Please verify your email address to access all features.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final auth = ref.watch(authControllerProvider);
                                      
                                      // Check cooldown
                                      final now = DateTime.now();
                                      final canSendEmail = _lastEmailSentTime == null || 
                                          now.difference(_lastEmailSentTime!) >= _emailCooldownDuration;
                                      final cooldownRemaining = _lastEmailSentTime != null && !canSendEmail
                                          ? _emailCooldownDuration - now.difference(_lastEmailSentTime!)
                                          : null;
                                      
                                      return SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: (auth.loading || !canSendEmail) ? null : () async {
                                            try {
                                              final authRepo = ref.read(authRepositoryProvider);
                                              await authRepo.resendEmailVerification();
                                              
                                              setState(() {
                                                _lastEmailSentTime = DateTime.now();
                                              });
                                              _startCooldownTimer();
                                              
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: const Text('✅ Verification email sent! Please check your inbox and spam folder.'),
                                                    backgroundColor: const Color(0xFF06D6A0),
                                                    duration: const Duration(seconds: 4),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                final errorMessage = e.toString().replaceFirst('Exception: ', '');
                                                // Show error in dialog for rate limiting to display full message
                                                final isRateLimit = errorMessage.toLowerCase().contains('too many');
                                                
                                                if (isRateLimit) {
                                                  // Set cooldown to prevent further attempts
                                                  setState(() {
                                                    _lastEmailSentTime = DateTime.now();
                                                  });
                                                  _startCooldownTimer();
                                                  
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Row(
                                                        children: [
                                                          Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                                          SizedBox(width: 8),
                                                          Expanded(child: Text('Rate Limit Exceeded')),
                                                        ],
                                                      ),
                                                      content: SingleChildScrollView(
                                                        child: Text(
                                                          errorMessage,
                                                          style: const TextStyle(fontSize: 14),
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: const Text('OK'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('⚠️ $errorMessage'),
                                                      backgroundColor: Colors.red,
                                                      duration: const Duration(seconds: 5),
                                                      action: SnackBarAction(
                                                        label: 'Dismiss',
                                                        textColor: Colors.white,
                                                        onPressed: () {},
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                          icon: auth.loading
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Icons.email_outlined, size: 18),
                                          label: Text(
                                            auth.loading
                                                ? 'Sending...'
                                                : cooldownRemaining != null
                                                    ? 'Please wait ${cooldownRemaining.inSeconds}s'
                                                    : 'Resend Verification Email',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _brand,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            disabledBackgroundColor: Colors.grey.shade300,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    if (_isEditMode)
                      _EditableInfoField(
                        label: 'Phone Number',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          return null;
                        },
                      )
                    else
                      _InfoField(label: 'Phone Number', value: profile?.phoneNumber ?? ''),
                    Row(
                      children: [
                        Expanded(
                          child: _isEditMode
                              ? _EditableInfoField(
                                  label: 'Tower Number',
                                  controller: _towerController,
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Tower number is required';
                                    }
                                    return null;
                                  },
                                )
                              : _InfoField(label: 'Tower Number', value: profile?.towerNumber ?? ''),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _isEditMode
                              ? _EditableInfoField(
                                  label: 'Room Number',
                                  controller: _roomController,
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Room number is required';
                                    }
                                    return null;
                                  },
                                )
                              : _InfoField(label: 'Room Number', value: profile?.roomNumber ?? ''),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              ),
              _CardSection(
                title: 'Security',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      readOnly: true,
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, color: _brand),
                        hintText: '••••••••',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _brand),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: auth.loading
                            ? null
                            : () async {
                                final currentPasswordController = TextEditingController();
                                final newPasswordController = TextEditingController();
                                final formKey = GlobalKey<FormState>();
                                
                                final result = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700)),
                                    content: Form(
                                      key: formKey,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            TextFormField(
                                              controller: currentPasswordController,
                                              obscureText: true,
                                              decoration: const InputDecoration(
                                                labelText: 'Current Password',
                                                prefixIcon: Icon(Icons.lock_outline),
                                              ),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Current password is required';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            TextFormField(
                                              controller: newPasswordController,
                                              obscureText: true,
                                              decoration: const InputDecoration(
                                                labelText: 'New Password',
                                                prefixIcon: Icon(Icons.lock),
                                                helperText: 'Minimum 6 characters',
                                              ),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'New password is required';
                                                }
                                                if (value.length < 6) {
                                                  return 'Password must be at least 6 characters';
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      Consumer(
                                        builder: (context, ref, child) {
                                          final authState = ref.watch(authControllerProvider);
                                          return ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _brand,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: authState.loading ? null : () async {
                                              if (formKey.currentState!.validate()) {
                                                Navigator.pop(dialogContext, true);
                                              }
                                            },
                                            child: const Text('Change Password'),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                                
                                if (result == true) {
                                  final currentPassword = currentPasswordController.text.trim();
                                  final newPassword = newPasswordController.text.trim();

                                  if (currentPassword.isEmpty || newPassword.isEmpty) {
                                    _showPasswordChangeDialog(
                                      success: false,
                                      errorMessage: 'Please fill in all fields.',
                                    );
                                    return;
                                  }

                                  try {
                                    await ref.read(authControllerProvider.notifier).changePassword(
                                      currentPassword: currentPassword,
                                      newPassword: newPassword,
                                    );

                                    if (!mounted) return;

                                    // ✅ SUCCESS POPUP
                                    _showPasswordChangeDialog(success: true);
                                  } on FirebaseAuthException catch (e) {
                                    String message = "Something went wrong.";

                                    switch (e.code) {
                                      case 'wrong-password':
                                        message = 'Your current password is incorrect.';
                                        break;
                                      case 'weak-password':
                                        message = 'Your new password is too weak.';
                                        break;
                                      case 'requires-recent-login':
                                        message = 'Please log in again before changing your password.';
                                        break;
                                      default:
                                        message = e.message ?? message;
                                    }

                                    if (!mounted) return;

                                    // ❌ FAILURE POPUP
                                    _showPasswordChangeDialog(
                                      success: false,
                                      errorMessage: message,
                                    );
                                  } catch (e) {
                                    if (!mounted) return;

                                    _showPasswordChangeDialog(
                                      success: false,
                                      errorMessage: "Something went wrong. Please try again.",
                                    );
                                  }
                                }
                              },
                        child: auth.loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_isEditMode) ...[
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: auth.loading ? null : _cancelEdit,
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: auth.loading ? null : _saveProfile,
                        child: auth.loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          setState(() {
                            _isEditMode = true;
                          });
                        },
                        child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await ref.read(authControllerProvider.notifier).logout();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out')));
                          }
                        },
                        child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context, WidgetRef ref, int currentIndex) {
    final profile = ref.watch(authControllerProvider).profile;
    final unreadCount = profile != null 
        ? ref.watch(unreadNotificationsProvider(profile.id))
        : const AsyncValue.data(0);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        switch (index) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/home/messages');
            break;
          case 2:
            context.go('/home/my-posts');
            break;
          case 3:
            // Already on account
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF00857A),
      unselectedItemColor: Colors.grey,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: unreadCount.when(
            data: (count) => count > 0
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.mail_outline),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: count > 9 
                              ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                              : const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: count > 9
                              ? const Text(
                                  '9+',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                )
                              : count > 0
                                  ? Text(
                                      count.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                  : null,
                        ),
                      ),
                    ],
                  )
                : const Icon(Icons.mail_outline),
            loading: () => const Icon(Icons.mail_outline),
            error: (_, __) => const Icon(Icons.mail_outline),
          ),
          label: 'Message',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list),
          label: 'My Post',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Account',
        ),
      ],
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 6)),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            readOnly: true,
            controller: TextEditingController(text: value),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _brand),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableInfoField extends StatelessWidget {
  const _EditableInfoField({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _brand, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


