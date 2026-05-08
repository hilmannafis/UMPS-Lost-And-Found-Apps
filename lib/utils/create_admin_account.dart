import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models/user_profile.dart';

/// Helper function to create an admin account in Firebase
/// Run this once to create your admin user
Future<void> createAdminAccount({
  required String email,
  required String password,
  String username = 'admin',
  String firstName = 'Admin',
  String lastName = 'User',
  String phoneNumber = '1234567890',
  String towerNumber = '1',
  String roomNumber = '1',
}) async {
  try {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    print('🔐 Creating admin account...');
    print('   Email: $email');

    // Create user in Firebase Auth
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    print('✅ User created in Firebase Auth: $uid');

    // Create user profile in Firestore with admin role
    final profile = UserProfile(
      id: uid,
      email: email,
      username: username,
      role: UserRole.admin,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      towerNumber: towerNumber,
      roomNumber: roomNumber,
      createdAt: DateTime.now(),
    );

    await firestore.collection('users').doc(uid).set(profile.toMap());

    print('✅ Admin profile created in Firestore');
    print('✅ Admin account created successfully!');
    print('   You can now login with:');
    print('   Email: $email');
    print('   Password: [your password]');
  } catch (e) {
    if (e is FirebaseAuthException) {
      if (e.code == 'email-already-in-use') {
        print('⚠️ Email already exists. User might already be registered.');
        print('   Try logging in with this email instead.');
      } else {
        print('❌ Error creating admin account: ${e.message}');
      }
    } else {
      print('❌ Error: $e');
    }
    rethrow;
  }
}

