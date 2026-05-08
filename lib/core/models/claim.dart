import 'package:cloud_firestore/cloud_firestore.dart';

enum ClaimStatus { pending, approved, rejected }

class Claim {
  Claim({
    required this.id,
    required this.itemId,
    required this.claimantId,
    required this.message,
    required this.evidencePhotos,
    this.status = ClaimStatus.pending,
    this.decidedBy,
    this.decidedAt,
    this.createdAt,
    this.meetLocation,
    this.meetTime,
  });

  final String id;
  final String itemId;
  final String claimantId;
  final String message;
  final List<String> evidencePhotos;
  final ClaimStatus status;
  final String? decidedBy;
  final DateTime? decidedAt;
  final DateTime? createdAt;
  final String? meetLocation;
  final DateTime? meetTime;

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'claimantId': claimantId,
      'message': message,
      'evidencePhotos': evidencePhotos,
      'status': status.name,
      'decidedBy': decidedBy,
      'decidedAt': decidedAt != null ? Timestamp.fromDate(decidedAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'meetLocation': meetLocation,
      'meetTime': meetTime != null ? Timestamp.fromDate(meetTime!) : null,
    };
  }

  factory Claim.fromMap(String id, Map<String, dynamic> data) {
    return Claim(
      id: id,
      itemId: data['itemId'] ?? '',
      claimantId: data['claimantId'] ?? '',
      message: data['message'] ?? '',
      evidencePhotos: List<String>.from(data['evidencePhotos'] ?? []),
      status: _statusFromString(data['status'] as String? ?? 'pending'),
      decidedBy: data['decidedBy'] as String?,
      decidedAt: (data['decidedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      meetLocation: data['meetLocation'] as String?,
      meetTime: (data['meetTime'] as Timestamp?)?.toDate(),
    );
  }

  static ClaimStatus _statusFromString(String raw) {
    switch (raw) {
      case 'approved':
        return ClaimStatus.approved;
      case 'rejected':
        return ClaimStatus.rejected;
      default:
        return ClaimStatus.pending;
    }
  }
}

