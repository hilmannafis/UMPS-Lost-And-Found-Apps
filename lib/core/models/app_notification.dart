import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.refId,
    this.read = false,
    this.itemId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final String refId;
  final bool read;
  final String? itemId;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'refId': refId,
      'read': read,
      'itemId': itemId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? '',
      refId: data['refId'] ?? '',
      read: data['read'] ?? false,
      itemId: data['itemId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

