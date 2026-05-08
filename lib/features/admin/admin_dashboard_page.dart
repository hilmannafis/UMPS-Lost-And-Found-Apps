import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:intl/intl.dart';

import '../../core/models/claim.dart';
import '../../core/models/item.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/auth_controller.dart';
import '../../core/providers/claim_providers.dart';
import '../../core/providers/item_providers.dart';
import '../../core/providers/user_providers.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          _AdminHomeTab(),
          _AdminProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _AdminHomeTab extends ConsumerWidget {
  const _AdminHomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current user profile
    final profile = ref.watch(authControllerProvider).profile;
    
    // Get current user ID for query
    final authUser = ref.watch(authStateProvider);
    final userId = authUser.value?.uid;
    
    // Total counts for stat cards
    final allUsers = ref.watch(allUsersStreamProvider);
    final allLostItems = ref.watch(itemsStreamProvider(ItemsQuery(type: ItemType.lost, userId: userId)));
    final allFoundItems = ref.watch(itemsStreamProvider(ItemsQuery(type: ItemType.found, userId: userId)));
    final allClaims = ref.watch(allClaimsProvider);

    // Recent items for activity feed
    final recentUsers = ref.watch(usersStreamProvider);
    final recentLostItems = ref.watch(itemsStreamProvider(ItemsQuery(type: ItemType.lost, userId: userId)));
    final recentFoundItems = ref.watch(itemsStreamProvider(ItemsQuery(type: ItemType.found, userId: userId)));
    final recentClaims = ref.watch(recentClaimsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            if (profile != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Center(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                      children: [
                        const TextSpan(text: 'Welcome '),
                        TextSpan(
                          text: profile.username,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const TextSpan(text: '!'),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Text('Admin Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00857A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => context.go('/admin/create-admin'),
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Create Admin'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00857A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => context.go('/admin/firebase-test'),
                    icon: const Icon(Icons.cloud),
                    label: const Text('Test Firebase'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00857A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => context.go('/admin/register-student'),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Register New Student', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00857A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => context.go('/admin/users'),
                icon: const Icon(Icons.people),
                label: const Text('Manage Users', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00857A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => context.go('/admin/items'),
                icon: const Icon(Icons.inventory_2),
                label: const Text('Manage Items', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 20),
            // Statistics Cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Users',
                    color: Colors.blue,
                    icon: Icons.people,
                    value: allUsers.maybeWhen(data: (d) => d.length, orElse: () => null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Lost Items',
                    color: Colors.orange,
                    icon: Icons.shopping_bag,
                    value: allLostItems.maybeWhen(data: (d) => d.length, orElse: () => null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Found Items',
                    color: Colors.green,
                    icon: Icons.handshake,
                    value: allFoundItems.maybeWhen(data: (d) => d.length, orElse: () => null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Total Claims',
                    color: Colors.purple,
                    icon: Icons.assignment,
                    value: allClaims.maybeWhen(data: (d) => d.length, orElse: () => null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent Activities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Recent Users
            _ActivitySection(
              title: 'Recent Users',
              activities: recentUsers.when(
                data: (users) => users.isEmpty
                    ? [
                        _ActivityItem(
                          icon: Icons.info_outline,
                          iconColor: Colors.grey,
                          title: 'No recent users',
                          subtitle: '',
                          date: DateTime.now(),
                          tag: null,
                        )
                      ]
                    : users.take(5).map((u) => _ActivityItem(
                          icon: Icons.person_add,
                          iconColor: Colors.blue,
                          title: 'New user registered',
                          subtitle: '${u.firstName} ${u.lastName} (${u.email})',
                          date: u.createdAt ?? DateTime.now(),
                          tag: null,
                        )).toList(),
                loading: () => [const _ActivityItem.loading()],
                error: (e, _) => [
                  _ActivityItem(
                    icon: Icons.error,
                    iconColor: Colors.red,
                    title: 'Error loading users',
                    subtitle: e.toString(),
                    date: DateTime.now(),
                    tag: null,
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Recent Claims
            _ActivitySection(
              title: 'Recent Claims',
              activities: recentClaims.when(
                data: (claims) => claims.isEmpty
                    ? [
                        _ActivityItem(
                          icon: Icons.info_outline,
                          iconColor: Colors.grey,
                          title: 'No recent claims',
                          subtitle: '',
                          date: DateTime.now(),
                          tag: null,
                        )
                      ]
                    : claims.take(5).map((c) => _ClaimActivityItem(
                          ref: ref,
                          claim: c,
                        )).toList(),
                loading: () => [const _ActivityItem.loading()],
                error: (e, _) => [
                  _ActivityItem(
                    icon: Icons.error,
                    iconColor: Colors.red,
                    title: 'Error loading claims',
                    subtitle: e.toString(),
                    date: DateTime.now(),
                    tag: null,
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Recent Lost Items
            _ActivitySection(
              title: 'Recent Lost Items',
              activities: recentLostItems.when(
                data: (items) => items.isEmpty
                    ? [
                        _ActivityItem(
                          icon: Icons.info_outline,
                          iconColor: Colors.grey,
                          title: 'No recent lost items',
                          subtitle: '',
                          date: DateTime.now(),
                          tag: null,
                        )
                      ]
                    : items.take(5).map((item) => _ItemActivityItem(
                          ref: ref,
                          icon: Icons.shopping_bag,
                          iconColor: Colors.orange,
                          title: item.title,
                          ownerId: item.ownerId,
                          date: item.createdAt ?? DateTime.now(),
                          tag: _StatusTag(
                            text: 'LOST',
                            color: Colors.orange,
                          ),
                        )).toList(),
                loading: () => [const _ActivityItem.loading()],
                error: (e, _) => [
                  _ActivityItem(
                    icon: Icons.error,
                    iconColor: Colors.red,
                    title: 'Error loading lost items',
                    subtitle: e.toString(),
                    date: DateTime.now(),
                    tag: null,
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Recent Found Items
            _ActivitySection(
              title: 'Recent Found Items',
              activities: recentFoundItems.when(
                data: (items) => items.isEmpty
                    ? [
                        _ActivityItem(
                          icon: Icons.info_outline,
                          iconColor: Colors.grey,
                          title: 'No recent found items',
                          subtitle: '',
                          date: DateTime.now(),
                          tag: null,
                        )
                      ]
                    : items.take(5).map((item) => _ItemActivityItem(
                          ref: ref,
                          icon: Icons.handshake,
                          iconColor: Colors.teal,
                          title: item.title,
                          ownerId: item.ownerId,
                          date: item.createdAt ?? DateTime.now(),
                          tag: _StatusTag(
                            text: 'FOUND',
                            color: Colors.teal,
                          ),
                        )).toList(),
                loading: () => [const _ActivityItem.loading()],
                error: (e, _) => [
                  _ActivityItem(
                    icon: Icons.error,
                    iconColor: Colors.red,
                    title: 'Error loading found items',
                    subtitle: e.toString(),
                    date: DateTime.now(),
                    tag: null,
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

}

class _AdminProfileTab extends ConsumerStatefulWidget {
  const _AdminProfileTab();

  @override
  ConsumerState<_AdminProfileTab> createState() => _AdminProfileTabState();
}

class _AdminProfileTabState extends ConsumerState<_AdminProfileTab> {
  bool _isEditMode = false;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;
  late TextEditingController _officeController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _departmentController = TextEditingController();
    _officeController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _officeController.dispose();
    super.dispose();
  }

  void _updateControllers(UserProfile? profile) {
    if (profile != null) {
      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
      _phoneController.text = profile.phoneNumber;
      _departmentController.text = profile.towerNumber;
      _officeController.text = profile.roomNumber;
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        await ref.read(authControllerProvider.notifier).updateProfile(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          towerNumber: _departmentController.text.trim(),
          roomNumber: _officeController.text.trim(),
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

    const brand = Color(0xFF00857A);
    
    // Initialize or update controllers when profile changes (but only if not in edit mode)
    if (profile != null && !_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isEditMode) {
          _updateControllers(profile);
        }
      });
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 6))],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: Colors.grey.shade200,
                    child: Text(
                      (profile?.firstName.isNotEmpty == true ? profile!.firstName[0] : '?').toUpperCase(),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: brand),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Chip(
                    label: Text(profile?.role.name.toUpperCase() ?? 'ADMIN'),
                    backgroundColor: Colors.blue.shade100,
                    labelStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                      _LabeledIconField(
                        label: 'Full Name',
                        icon: Icons.person,
                        value: profile != null ? '${profile.firstName} ${profile.lastName}' : '',
                      ),
                    _LabeledIconField(
                      label: 'Email',
                      icon: Icons.email_outlined,
                      value: profile?.email ?? '',
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
                      _LabeledIconField(
                        label: 'Phone Number',
                        icon: Icons.phone,
                        value: profile?.phoneNumber ?? '',
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: _isEditMode
                              ? _EditableInfoField(
                                  label: 'Department',
                                  controller: _departmentController,
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Department is required';
                                    }
                                    return null;
                                  },
                                )
                              : _LabeledIconField(
                                  label: 'Department',
                                  icon: Icons.badge,
                                  value: profile?.towerNumber ?? '',
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _isEditMode
                              ? _EditableInfoField(
                                  label: 'Office',
                                  controller: _officeController,
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Office is required';
                                    }
                                    return null;
                                  },
                                )
                              : _LabeledIconField(
                                  label: 'Office',
                                  icon: Icons.apartment,
                                  value: profile?.roomNumber ?? '',
                                ),
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
                      prefixIcon: const Icon(Icons.lock_outline, color: brand),
                      hintText: '••••••••',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: brand),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ChangePasswordButton(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _isEditMode
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: auth.loading ? null : _saveProfile,
                          child: auth.loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brand,
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
                if (_isEditMode) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _cancelEdit,
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ] else ...[
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
            const SizedBox(height: 16),
            if (profile != null)
              Text(
                'Account ID: ${profile.id}\nMember since: ${profile.createdAt?.year ?? DateTime.now().year}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ChangePasswordButton> createState() => _ChangePasswordButtonState();
}

class _ChangePasswordButtonState extends ConsumerState<_ChangePasswordButton> {
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
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
                              backgroundColor: const Color(0xFF00857A),
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
            : const Text('Change Password'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.color,
    required this.icon,
    this.value,
  });

  final String title;
  final Color color;
  final IconData icon;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 28),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value?.toString() ?? '0',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.title, required this.activities});

  final String title;
  final List<Widget> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...activities.map((activity) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: activity,
            )),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.date,
    this.tag,
  });

  const _ActivityItem.loading()
      : icon = Icons.hourglass_empty,
        iconColor = Colors.grey,
        title = 'Loading...',
        subtitle = '',
        date = null,
        tag = null;

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final DateTime? date;
  final Widget? tag;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy, HH:mm').format(date!),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          if (tag != null) tag!,
        ],
      ),
    );
  }
}

class _ItemActivityItem extends ConsumerWidget {
  const _ItemActivityItem({
    required this.ref,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.ownerId,
    required this.date,
    required this.tag,
  });

  final WidgetRef ref;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String ownerId;
  final DateTime date;
  final Widget tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerProfile = ref.watch(userProfileProvider(ownerId));
    final ownerName = ownerProfile.maybeWhen(
      data: (profile) => profile != null
          ? '${profile.firstName} ${profile.lastName}'.trim().isNotEmpty
              ? '${profile.firstName} ${profile.lastName}'.trim()
              : profile.username
          : ownerId,
      orElse: () => ownerId,
    );

    return _ActivityItem(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: 'by $ownerName',
      date: date,
      tag: tag,
    );
  }
}

class _ClaimActivityItem extends ConsumerWidget {
  const _ClaimActivityItem({required this.ref, required this.claim});

  final WidgetRef ref;
  final Claim claim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemStreamProvider(claim.itemId));
    final claimant = ref.watch(userProfileProvider(claim.claimantId));
    
    final itemTitle = item.maybeWhen(
      data: (i) => i?.title ?? 'Item ${claim.itemId}',
      orElse: () => 'Item ${claim.itemId}',
    );
    
    final claimantName = claimant.maybeWhen(
      data: (profile) => profile != null
          ? '${profile.firstName} ${profile.lastName}'.trim().isNotEmpty
              ? '${profile.firstName} ${profile.lastName}'.trim()
              : profile.username
          : 'Someone',
      orElse: () => 'Someone',
    );

    final statusColor = claim.status == ClaimStatus.approved
        ? Colors.green
        : claim.status == ClaimStatus.rejected
            ? Colors.red
            : Colors.orange;

    return _ActivityItem(
      icon: Icons.assignment,
      iconColor: Colors.blue,
      title: 'Claim by $claimantName',
      subtitle: itemTitle,
      date: claim.createdAt ?? DateTime.now(),
      tag: _StatusTag(
        text: claim.status.name.toUpperCase(),
        color: statusColor,
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
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

class _LabeledIconField extends StatelessWidget {
  const _LabeledIconField({required this.label, required this.icon, required this.value});

  final String label;
  final IconData icon;
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
              prefixIcon: Icon(icon, color: const Color(0xFF00857A)),
              filled: true,
              fillColor: Colors.grey.shade100,
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
    const brand = Color(0xFF00857A);
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
                borderSide: const BorderSide(color: brand, width: 2),
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


