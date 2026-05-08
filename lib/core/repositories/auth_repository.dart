import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/user_profile.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final _users = 'users';

  Stream<User?> get authState => _auth.authStateChanges();

  Stream<List<UserProfile>> watchUsers({int? limit}) {
    Query<Map<String, dynamic>> query = _firestore.collection(_users).orderBy('createdAt', descending: true);
    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snap) => snap.docs.map((doc) => UserProfile.fromMap(doc.id, doc.data())).toList());
  }

  Stream<List<UserProfile>> watchAllUsers() {
    return _firestore
        .collection(_users)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => UserProfile.fromMap(doc.id, doc.data())).toList());
  }

  Stream<UserProfile?> watchUser(String userId) {
    return _firestore
        .collection(_users)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null ? UserProfile.fromMap(doc.id, doc.data()!) : null);
  }

  Future<UserProfile?> currentProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snap = await _firestore.collection(_users).doc(user.uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return UserProfile.fromMap(snap.id, snap.data()!);
  }

  /// Update password - requires reauthentication for security
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    if (user.email == null) throw Exception('User email not available');
    
    try {
      print('🔐 Starting password update process for: ${user.email}');
      
      // Trim whitespace from passwords
      final finalCurrentPassword = currentPassword.trim();
      final finalNewPassword = newPassword.trim();
      
      // Basic validation - only check length
      if (finalNewPassword.length < 6) {
        throw Exception('New password must be at least 6 characters long.');
      }
      
      // Let Firebase handle the "same password" check - it will work fine
      
      // Reauthenticate user with current password
      print('🔐 Reauthenticating user with current password...');
      print('   Email: ${user.email}');
      print('   Current password length: ${finalCurrentPassword.length}');
      
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: finalCurrentPassword,
      );
      
      try {
        await user.reauthenticateWithCredential(credential);
        print('✅ Reauthentication successful - current password is correct');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          print('❌ Reauthentication failed: Current password is incorrect');
          throw Exception('Current password is incorrect. Please enter the correct current password and try again.');
        }
        rethrow; // Re-throw other errors to be caught by outer catch
      }
      
      // Now update the password
      print('🔑 Updating password to new value...');
      print('   Current password length: ${finalCurrentPassword.length}');
      print('   New password length: ${finalNewPassword.length}');
      
      // Call updatePassword - this MUST complete successfully for password to change
      print('📞 Calling Firebase updatePassword() with new password...');
      print('   This will update the password in Firebase Authentication servers');
      
      try {
        // This is the critical call - if this succeeds, password IS changed in Firebase
        await user.updatePassword(finalNewPassword);
        print('✅ updatePassword() completed successfully!');
        print('   ✅ Password has been updated in Firebase Authentication');
        print('   ✅ The new password is now active on Firebase servers');
      } catch (updateError) {
        print('❌ CRITICAL: Password update call failed!');
        print('❌ Error: $updateError');
        print('❌ Error type: ${updateError.runtimeType}');
        if (updateError is FirebaseAuthException) {
          print('❌ Firebase Auth Error Code: ${updateError.code}');
          print('❌ Firebase Auth Error Message: ${updateError.message}');
          print('❌ Full error: ${updateError.toString()}');
        }
        // Re-throw so the UI can show the error
        rethrow;
      }
      
      // Wait a moment for Firebase to fully process
      print('⏳ Waiting 1 second for Firebase to finalize the change...');
      await Future.delayed(const Duration(seconds: 1));
      
      // Reload user to sync with server (optional but good practice)
      print('🔄 Reloading user data from Firebase...');
      try {
        await user.reload();
        print('✅ User data reloaded');
      } catch (reloadError) {
        print('⚠️ Note: User reload had an issue: $reloadError');
        print('   This is usually not critical - password should still be updated');
      }
      
      // Final verification
      final reloadedUser = _auth.currentUser;
      if (reloadedUser == null) {
        throw Exception('User session lost after password update - this should not happen');
      }
      
      print('');
      print('═══════════════════════════════════════════════════════');
      print('✅ PASSWORD UPDATE SUCCESSFUL!');
      print('═══════════════════════════════════════════════════════');
      print('📧 User: ${reloadedUser.email}');
      print('🆔 UID: ${reloadedUser.uid}');
      print('🔑 Your password has been changed in Firebase Authentication');
      print('');
      print('📝 IMPORTANT: To verify the change worked:');
      print('   1. Log out of the app');
      print('   2. Log back in using your NEW password');
      print('   3. If login succeeds, the password change worked!');
      print('═══════════════════════════════════════════════════════');
      
    } on FirebaseAuthException catch (e) {
      print('⚠️ Firebase Auth Error: ${e.code} - ${e.message}');
      print('⚠️ Error details: ${e.toString()}');
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          // invalid-credential can occur during reauthentication if current password is wrong
          throw Exception('Current password is incorrect. Please check your current password and try again.');
        case 'weak-password':
          throw Exception('New password is too weak. Please use a stronger password (at least 6 characters).');
        case 'requires-recent-login':
          throw Exception('For security, please log out and log in again before changing your password.');
        case 'network-request-failed':
          throw Exception('Network error. Please check your internet connection and try again.');
        case 'too-many-requests':
          throw Exception('Too many password change attempts. Please wait a few minutes and try again.');
        default:
          final errorMsg = e.message ?? e.code;
          throw Exception('Failed to update password: $errorMsg');
      }
    } catch (e) {
      print('⚠️ Error updating password: $e');
      print('⚠️ Error type: ${e.runtimeType}');
      print('⚠️ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Check if email already exists in Firestore
  Future<bool> emailExists(String email) async {
    try {
      final query = await _firestore
          .collection(_users)
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('⚠️ Error checking email existence: $e');
      return false;
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await _saveFcmToken(credential.user?.uid);
      return credential;
    } on FirebaseAuthException catch (e) {
      // Re-throw FirebaseAuthException so login page can handle specific error codes
      // This ensures 'wrong-password' and 'invalid-credential' errors are properly detected
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserProfile> register({
    required String email,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String towerNumber,
    required String roomNumber,
    required UserRole role,
    File? profileImage,
  }) async {
    final emailLower = email.trim().toLowerCase();
    
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailLower,
        password: password,
      );
    final user = credential.user!;
    final uid = user.uid;

    // Send email verification
    String? emailError;
    try {
      await user.sendEmailVerification();
      print('✅ Verification email sent successfully to: $email');
    } catch (e) {
      // Log error but don't fail registration if email sending fails
      emailError = e.toString();
      print('⚠️ Failed to send verification email: $e');
      print('⚠️ Error details: ${emailError}');
    }
    
    // Store email error in user metadata for later retrieval if needed
    // Note: We don't throw here to allow registration to complete

    String? photoUrl;
    if (profileImage != null) {
      final ref = _storage.ref().child('users/$uid/${const Uuid().v4()}.jpg');
      await ref.putFile(profileImage);
      photoUrl = await ref.getDownloadURL();
    }

    final profile = UserProfile(
      id: uid,
      email: email,
      username: username,
      role: role,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      towerNumber: towerNumber,
      roomNumber: roomNumber,
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
    );

    await _firestore.collection(_users).doc(uid).set(profile.toMap());
    await _saveFcmToken(uid);
    return profile;
    } on FirebaseAuthException catch (e) {
      // Re-throw FirebaseAuthException directly so UI can handle specific error codes
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Resend email verification to the current user
  /// 
  /// Note: Make sure email verification is enabled in Firebase Console:
  /// 1. Go to Firebase Console > Authentication > Settings > Templates
  /// 2. Ensure "Email address verification" template is enabled
  /// 3. Check that your authorized domains are configured
  /// 4. Verify Email/Password sign-in method is enabled
  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }
    if (user.email == null || user.email!.isEmpty) {
      throw Exception('User email is not available');
    }
    
    // Get email from Firebase Auth (this is the email that will receive verification)
    final authEmail = user.email!;
    
    // Get email from Firestore profile (this is what's displayed in the UI)
    final profile = await currentProfile();
    final profileEmail = profile?.email;
    
    // Check for email mismatch
    if (profileEmail != null && 
        profileEmail.isNotEmpty && 
        profileEmail.toLowerCase() != authEmail.toLowerCase()) {
      print('⚠️ EMAIL MISMATCH DETECTED!');
      print('   Firebase Auth email: $authEmail');
      print('   Firestore profile email: $profileEmail');
      print('   Verification email will be sent to: $authEmail (Firebase Auth email)');
      
      throw Exception(
        'Email mismatch detected!\n\n'
        'You are logged in as: $authEmail\n'
        'But your profile shows: $profileEmail\n\n'
        'The verification email will be sent to: $authEmail\n\n'
        'To verify $profileEmail, please:\n'
        '1. Log out of this account\n'
        '2. Log in with: $profileEmail\n'
        '3. Then request verification email again'
      );
    }
    
    final userEmail = authEmail;
    print('📧 Attempting to send verification email to: $userEmail');
    print('📧 Firebase Auth email: $userEmail');
    if (profileEmail != null && profileEmail != userEmail) {
      print('⚠️ Warning: Profile email ($profileEmail) differs from Auth email ($userEmail)');
    }
    
    try {
      // Reload user to get latest emailVerified status
      await user.reload();
      final reloadedUser = _auth.currentUser;
      if (reloadedUser?.emailVerified == true) {
        print('✅ Email is already verified for: $userEmail');
        throw Exception('Email is already verified');
      }
      
      print('📤 Sending verification email...');
      
      // Send verification email
      // Note: Firebase Dynamic Links is shutting down, but email verification still works
      // The ActionCodeSettings helps ensure proper email delivery
      try {
        // Use the Firebase project domain for the verification link
        final actionCodeSettings = ActionCodeSettings(
          url: 'https://lostandfound-c39bd.firebaseapp.com/__/auth/action',
          handleCodeInApp: false,
        );
        print('📧 Using ActionCodeSettings with URL: ${actionCodeSettings.url}');
        await user.sendEmailVerification(actionCodeSettings);
        print('✅ Verification email sent with ActionCodeSettings');
      } catch (e) {
        // Fallback: Try without ActionCodeSettings if the above fails
        print('⚠️ Failed with ActionCodeSettings: $e');
        print('🔄 Trying without ActionCodeSettings...');
        await user.sendEmailVerification();
        print('✅ Verification email sent without ActionCodeSettings');
      }
      
      print('✅ Verification email sent successfully to: $userEmail');
      print('📬 Email Details:');
      print('   • Recipient: $userEmail');
      print('   • Sender: noreply@lostandfound-c39bd.firebaseapp.com');
      print('   • Subject: "Verify your email for Lost & Found App"');
      print('   • Please check: Inbox, Spam, Junk, Promotions folders');
      print('   • If not received within 5 minutes, check Firebase Console > Authentication > Users');
      
    } on FirebaseAuthException catch (e) {
      print('⚠️ Firebase Auth Error: ${e.code} - ${e.message}');
      print('⚠️ Stack trace: ${e.stackTrace}');
      
      // Provide user-friendly error messages
      switch (e.code) {
        case 'too-many-requests':
          throw Exception(
            'Too many verification email requests detected. Firebase has temporarily blocked requests from this device.\n\n'
            'Please wait 15-30 minutes before trying again. If the problem persists, try:\n'
            '• Closing and reopening the app\n'
            '• Checking your spam/junk folder - the email might already be sent\n'
            '• Contacting support if you need immediate verification'
          );
        case 'network-request-failed':
          throw Exception('Network error. Please check your internet connection and try again.');
        case 'invalid-email':
          throw Exception('Invalid email address: $userEmail. Please contact support.');
        case 'missing-continue-uri':
          throw Exception(
            'Email configuration error. Please check Firebase Console:\n'
            '1. Authentication > Settings > Authorized domains\n'
            '2. Authentication > Settings > Templates > Email address verification\n'
            '3. Ensure Email/Password sign-in method is enabled'
          );
        case 'user-not-found':
          throw Exception('User account not found. Please sign out and sign in again.');
        default:
          final errorMsg = e.message ?? e.code;
          throw Exception(
            'Failed to send verification email: $errorMsg\n\n'
            'Troubleshooting steps:\n'
            '1. Check Firebase Console > Authentication > Settings > Templates\n'
            '2. Verify Email/Password sign-in method is enabled\n'
            '3. Check authorized domains in Firebase Console\n'
            '4. Check spam/junk folder\n'
            '5. Contact support if issue persists'
          );
      }
    } catch (e) {
      print('⚠️ Error sending verification email: $e');
      print('⚠️ Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Resend email verification by email (for logged out users)
  Future<void> resendEmailVerificationByEmail(String email) async {
    // Note: Firebase doesn't support sending verification email without user being logged in
    // This would require using Firebase Admin SDK on backend
    // For now, we'll throw an informative error
    throw Exception('Please sign in first to resend verification email. Or use "Forgot Password" to reset.');
  }

  /// Update current user's own profile
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? towerNumber,
    String? roomNumber,
    File? profileImage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    
    final userId = user.uid;
    final userDoc = _firestore.collection(_users).doc(userId);
    final currentData = await userDoc.get();
    
    if (!currentData.exists) {
      throw Exception('User profile not found');
    }

    final currentProfile = UserProfile.fromMap(userId, currentData.data()!);
    
    // Upload new profile image if provided
    String? photoUrl = currentProfile.photoUrl;
    if (profileImage != null) {
      final ref = _storage.ref().child('users/$userId/${const Uuid().v4()}.jpg');
      await ref.putFile(profileImage);
      photoUrl = await ref.getDownloadURL();
    }

    // Update Firestore document
    final updatedProfile = UserProfile(
      id: userId,
      email: currentProfile.email,
      username: currentProfile.username,
      role: currentProfile.role,
      firstName: firstName ?? currentProfile.firstName,
      lastName: lastName ?? currentProfile.lastName,
      phoneNumber: phoneNumber ?? currentProfile.phoneNumber,
      towerNumber: towerNumber ?? currentProfile.towerNumber,
      roomNumber: roomNumber ?? currentProfile.roomNumber,
      photoUrl: photoUrl,
      createdAt: currentProfile.createdAt,
    );

    await userDoc.update(updatedProfile.toMap());
  }

  /// Update user profile (admin only)
  Future<void> updateUser({
    required String userId,
    String? email,
    String? username,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? towerNumber,
    String? roomNumber,
    UserRole? role,
    File? profileImage,
  }) async {
    final userDoc = _firestore.collection(_users).doc(userId);
    final currentData = await userDoc.get();
    
    if (!currentData.exists) {
      throw Exception('User not found');
    }

    final currentProfile = UserProfile.fromMap(userId, currentData.data()!);
    
    // Note: Email update in Firebase Auth requires the user to be signed in
    // For admin updates, we only update Firestore. Email change in Auth
    // should be handled separately or via Admin SDK

    // Upload new profile image if provided
    String? photoUrl = currentProfile.photoUrl;
    if (profileImage != null) {
      final ref = _storage.ref().child('users/$userId/${const Uuid().v4()}.jpg');
      await ref.putFile(profileImage);
      photoUrl = await ref.getDownloadURL();
    }

    // Update Firestore document
    final updatedProfile = UserProfile(
      id: userId,
      email: email ?? currentProfile.email,
      username: username ?? currentProfile.username,
      role: role ?? currentProfile.role,
      firstName: firstName ?? currentProfile.firstName,
      lastName: lastName ?? currentProfile.lastName,
      phoneNumber: phoneNumber ?? currentProfile.phoneNumber,
      towerNumber: towerNumber ?? currentProfile.towerNumber,
      roomNumber: roomNumber ?? currentProfile.roomNumber,
      photoUrl: photoUrl,
      createdAt: currentProfile.createdAt,
    );

    await userDoc.update(updatedProfile.toMap());
  }

  /// Delete user (admin only) - deletes from Firestore
  /// Note: Firebase Auth user deletion requires Admin SDK on backend
  Future<void> deleteUser(String userId) async {
    // Delete from Firestore
    await _firestore.collection(_users).doc(userId).delete();
    
    // Note: To delete from Firebase Auth, you need to use Admin SDK on backend
    // For now, we only delete from Firestore. The user profile will be removed
    // but the Auth account will remain (though they won't be able to access the app)
  }

  Future<void> _saveFcmToken(String? uid) async {
    if (uid == null) return;
    try {
      // Request permission first
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        print('⚠️ FCM token is null for user $uid');
        return;
      }
      
      await _firestore.collection(_users).doc(uid).set(
            {'fcmToken': token},
            SetOptions(merge: true),
          );
      print('✅ FCM token saved for user $uid: ${token.substring(0, 20)}...');
      
      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        if (uid != null) {
          await _firestore.collection(_users).doc(uid).set(
                {'fcmToken': newToken},
                SetOptions(merge: true),
              );
          print('✅ FCM token refreshed for user $uid');
        }
      });
    } catch (e) {
      print('⚠️ Failed to save FCM token: $e');
    }
  }
  
  /// Manually refresh and save FCM token (can be called from UI)
  Future<void> refreshFcmToken() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _saveFcmToken(user.uid);
  }
}

