import 'package:cloud_firestore/cloud_firestore.dart';

enum ItemType { lost, found }
enum ItemStatus { open, claimed, resolved, rejected }

class Item {
  Item({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.categoryId,
    this.subcategoryId,
    required this.ownerId,
    required this.photos,
    required this.towerNumber,
    required this.roomNumber,
    this.status = ItemStatus.open,
    this.contactNumber,
    this.lostFoundDate,
    this.lostFoundTime,
    this.verifiedBy,
    this.verifiedAt,
    this.claimedBy,
    this.createdAt,
    this.imageEmbedding,
    this.dominantColors,
    this.dominantColorName,
    this.imageHash,
  });

  final String id;
  final ItemType type;
  final String title;
  final String description;
  final String categoryId;
  final String? subcategoryId;
  final String ownerId;
  final List<String> photos;
  final String towerNumber;
  final String roomNumber;
  final ItemStatus status;
  final String? contactNumber;
  final DateTime? lostFoundDate;
  final String? lostFoundTime;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? claimedBy;
  final DateTime? createdAt;
  final List<double>? imageEmbedding;
  final List<Map<String, int>>? dominantColors;
  final String? dominantColorName;
  final String? imageHash;

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'subcategoryId': subcategoryId,
      'ownerId': ownerId,
      'photos': photos,
      'towerNumber': towerNumber,
      'roomNumber': roomNumber,
      'status': status.name,
      'contactNumber': contactNumber,
      'lostFoundDate': lostFoundDate != null ? Timestamp.fromDate(lostFoundDate!) : null,
      'lostFoundTime': lostFoundTime,
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'claimedBy': claimedBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'imageEmbedding': imageEmbedding, // Store as array of doubles in Firestore
      'dominantColors': dominantColors, // Store as array of maps in Firestore
      'dominantColorName': dominantColorName, // Store color name for simple matching
      'imageHash': imageHash, // Store image hash string for perceptual matching
    };
  }

  factory Item.fromMap(String id, Map<String, dynamic> data) {
    return Item(
      id: id,
      type: _typeFromString(data['type'] as String? ?? 'lost'),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      categoryId: data['categoryId'] ?? '',
      subcategoryId: data['subcategoryId'] as String?,
      ownerId: data['ownerId'] ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      towerNumber: data['towerNumber'] ?? '',
      roomNumber: data['roomNumber'] ?? '',
      status: _statusFromString(data['status'] as String? ?? 'open'),
      contactNumber: data['contactNumber'] as String?,
      lostFoundDate: (data['lostFoundDate'] as Timestamp?)?.toDate(),
      lostFoundTime: data['lostFoundTime'] as String?,
      verifiedBy: data['verifiedBy'] as String?,
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      claimedBy: data['claimedBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      imageEmbedding: data['imageEmbedding'] != null 
          ? List<double>.from((data['imageEmbedding'] as List).map((e) => (e as num).toDouble()))
          : null,
      dominantColors: data['dominantColors'] != null
          ? List<Map<String, int>>.from((data['dominantColors'] as List).map((e) => Map<String, int>.from(e as Map)))
          : null,
      dominantColorName: data['dominantColorName'] as String?,
      imageHash: data['imageHash'] as String?,
    );
  }

  static ItemType _typeFromString(String raw) => raw == 'found' ? ItemType.found : ItemType.lost;
  static ItemStatus _statusFromString(String raw) {
    switch (raw) {
      case 'claimed':
        return ItemStatus.claimed;
      case 'resolved':
        return ItemStatus.resolved;
      case 'rejected':
        return ItemStatus.rejected;
      default:
        return ItemStatus.open;
    }
  }
}
