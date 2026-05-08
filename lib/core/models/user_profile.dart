import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { resident, admin }

class UserProfile {
  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.towerNumber,
    required this.roomNumber,
    this.photoUrl,
    this.createdAt,
  });

  final String id;
  final String email;
  final String username;
  final UserRole role;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String towerNumber;
  final String roomNumber;
  final String? photoUrl;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'role': role.name,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'towerNumber': towerNumber,
      'roomNumber': roomNumber,
      'photoUrl': photoUrl,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory UserProfile.fromMap(String id, Map<String, dynamic> data) {
    return UserProfile(
      id: id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      role: _roleFromString(data['role'] as String? ?? 'resident'),
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      towerNumber: data['towerNumber'] ?? '',
      roomNumber: data['roomNumber'] ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static UserRole _roleFromString(String raw) {
    return raw == 'admin' ? UserRole.admin : UserRole.resident;
  }
}

