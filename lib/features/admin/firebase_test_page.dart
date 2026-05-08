import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_controller.dart';
import '../../core/repositories/auth_repository.dart';

class FirebaseTestPage extends ConsumerStatefulWidget {
  const FirebaseTestPage({super.key});

  @override
  ConsumerState<FirebaseTestPage> createState() => _FirebaseTestPageState();
}

class _FirebaseTestPageState extends ConsumerState<FirebaseTestPage> {
  String _status = 'Initializing...';
  List<String> _logs = [];
  int _userCount = 0;
  int _itemCount = 0;
  int _claimCount = 0;

  @override
  void initState() {
    super.initState();
    _testFirebaseConnection();
  }

  Future<void> _testFirebaseConnection() async {
    setState(() {
      _logs.clear();
      _status = 'Testing Firebase connection...';
      _logs.add('🔍 Starting Firebase connection test...');
    });

    try {
      // Test 1: Check Firebase Auth
      _logs.add('\n✅ Test 1: Firebase Auth');
      final auth = FirebaseAuth.instance;
      _logs.add('   Current user: ${auth.currentUser?.email ?? "Not signed in"}');
      _logs.add('   Auth instance: ${auth.app.name}');

      // Test 2: Check Firestore connection
      _logs.add('\n✅ Test 2: Firestore Connection');
      final firestore = FirebaseFirestore.instance;
      _logs.add('   Firestore instance: ${firestore.app.name}');

      // Test 3: Try to read users collection
      _logs.add('\n✅ Test 3: Reading Users Collection');
      try {
        final usersSnapshot = await firestore.collection('users').limit(5).get();
        _userCount = usersSnapshot.docs.length;
        _logs.add('   Found $_userCount users in Firestore');
        if (usersSnapshot.docs.isNotEmpty) {
          _logs.add('   Sample user data:');
          for (var doc in usersSnapshot.docs.take(3)) {
            final data = doc.data();
            _logs.add('     - ${data['email'] ?? 'No email'} (${data['username'] ?? 'No username'})');
          }
        } else {
          _logs.add('   ⚠️ No users found in database');
        }
      } catch (e) {
        _logs.add('   ❌ Error reading users: $e');
      }

      // Test 4: Try to read items collection
      _logs.add('\n✅ Test 4: Reading Items Collection');
      try {
        final itemsSnapshot = await firestore.collection('items').limit(5).get();
        _itemCount = itemsSnapshot.docs.length;
        _logs.add('   Found $_itemCount items in Firestore');
        if (itemsSnapshot.docs.isNotEmpty) {
          _logs.add('   Sample item data:');
          for (var doc in itemsSnapshot.docs.take(3)) {
            final data = doc.data();
            _logs.add('     - ${data['title'] ?? 'No title'} (${data['type'] ?? 'No type'})');
          }
        } else {
          _logs.add('   ⚠️ No items found in database');
        }
      } catch (e) {
        _logs.add('   ❌ Error reading items: $e');
      }

      // Test 5: Try to read claims collection
      _logs.add('\n✅ Test 5: Reading Claims Collection');
      try {
        final claimsSnapshot = await firestore.collection('claims').limit(5).get();
        _claimCount = claimsSnapshot.docs.length;
        _logs.add('   Found $_claimCount claims in Firestore');
        if (claimsSnapshot.docs.isNotEmpty) {
          _logs.add('   Sample claim data:');
          for (var doc in claimsSnapshot.docs.take(3)) {
            final data = doc.data();
            _logs.add('     - Claim for item: ${data['itemId'] ?? 'No itemId'}');
          }
        } else {
          _logs.add('   ⚠️ No claims found in database');
        }
      } catch (e) {
        _logs.add('   ❌ Error reading claims: $e');
      }

      // Test 6: Check current user profile
      _logs.add('\n✅ Test 6: Current User Profile');
      final authState = ref.read(authControllerProvider);
      if (authState.profile != null) {
        final profile = authState.profile!;
        _logs.add('   Logged in as: ${profile.email}');
        _logs.add('   Username: ${profile.username}');
        _logs.add('   Role: ${profile.role.name}');
        _logs.add('   Name: ${profile.firstName} ${profile.lastName}');
      } else {
        _logs.add('   ⚠️ No user profile loaded (not logged in)');
      }

      setState(() {
        _status = '✅ Firebase connection successful!';
        _logs.add('\n🎉 All tests completed!');
      });
    } catch (e) {
      setState(() {
        _status = '❌ Firebase connection failed!';
        _logs.add('\n❌ Error: $e');
      });
    }
  }

  Future<void> _testLogin() async {
    setState(() {
      _logs.add('\n🔐 Testing Login...');
      _status = 'Testing login...';
    });

    try {
      // Try to get current auth state
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      
      if (currentUser != null) {
        _logs.add('   ✅ Already logged in as: ${currentUser.email}');
        _logs.add('   User ID: ${currentUser.uid}');
        
        // Try to fetch user profile from Firestore
        final firestore = FirebaseFirestore.instance;
        final userDoc = await firestore.collection('users').doc(currentUser.uid).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          _logs.add('   ✅ User profile found in Firestore:');
          _logs.add('     Email: ${userData['email']}');
          _logs.add('     Username: ${userData['username']}');
          _logs.add('     Role: ${userData['role']}');
        } else {
          _logs.add('   ⚠️ User profile not found in Firestore');
        }
      } else {
        _logs.add('   ⚠️ Not logged in. Please login first.');
      }
      
      setState(() {
        _status = 'Login test completed';
      });
    } catch (e) {
      setState(() {
        _status = 'Login test failed';
        _logs.add('   ❌ Error: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Connection Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _testFirebaseConnection,
            tooltip: 'Refresh test',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: _status.contains('✅') ? Colors.green.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $_status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _status.contains('✅') ? Colors.green.shade900 : Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatChip(label: 'Users', count: _userCount),
                        const SizedBox(width: 8),
                        _StatChip(label: 'Items', count: _itemCount),
                        const SizedBox(width: 8),
                        _StatChip(label: 'Claims', count: _claimCount),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _testLogin,
              icon: const Icon(Icons.login),
              label: const Text('Test Login Status'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Test Logs:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                _logs.join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $count'),
      backgroundColor: Colors.blue.shade50,
    );
  }
}

