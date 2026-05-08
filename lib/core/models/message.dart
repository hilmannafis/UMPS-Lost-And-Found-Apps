import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, claim, image }

class Message {
  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.itemId,
    required this.text,
    this.read = false,
    this.createdAt,
    this.type = MessageType.text,
    this.claimId,
    this.imageUrl,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String itemId;
  final String text;
  final bool read;
  final DateTime? createdAt;
  final MessageType type;
  final String? claimId;
  final String? imageUrl;

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'itemId': itemId,
      'text': text,
      'read': read,
      'type': type.name,
      'claimId': claimId,
      'imageUrl': imageUrl,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory Message.fromMap(String id, Map<String, dynamic> data) {
    return Message(
      id: id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      itemId: data['itemId'] ?? '',
      text: data['text'] ?? '',
      read: data['read'] ?? false,
      type: _typeFromString(data['type'] as String? ?? 'text'),
      claimId: data['claimId'] as String?,
      imageUrl: data['imageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static MessageType _typeFromString(String raw) {
    switch (raw) {
      case 'claim':
        return MessageType.claim;
      case 'image':
        return MessageType.image;
      default:
        return MessageType.text;
    }
  }
}

