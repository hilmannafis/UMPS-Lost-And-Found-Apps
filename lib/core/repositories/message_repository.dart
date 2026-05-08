import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';

class MessageRepository {
  MessageRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  // Get chat ID from two user IDs (consistent ordering)
  String _getChatId(String userId1, String userId2, String itemId) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}_$itemId';
  }

  // Watch messages for a chat
  Stream<List<Message>> watchMessages(String userId1, String userId2, String itemId) {
    final chatId = _getChatId(userId1, userId2, itemId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Message.fromMap(doc.id, doc.data())).toList());
  }

  // Send a message
  Future<Message> sendMessage({
    required String senderId,
    required String receiverId,
    required String itemId,
    required String text,
    String? imageUrl,
  }) async {
    final chatId = _getChatId(senderId, receiverId, itemId);
    final messagesRef = _firestore.collection('chats').doc(chatId).collection('messages');
    
    // Create message document
    final messageDoc = messagesRef.doc();
    final message = Message(
      id: messageDoc.id,
      senderId: senderId,
      receiverId: receiverId,
      itemId: itemId,
      text: text,
      read: false,
      createdAt: DateTime.now(),
      type: imageUrl != null ? MessageType.image : MessageType.text,
      imageUrl: imageUrl,
    );

    await messageDoc.set(message.toMap());

    // Update chat metadata
    final lastMessageText = imageUrl != null ? '📷 Photo' : text;
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [senderId, receiverId],
      'itemId': itemId,
      'lastMessage': lastMessageText,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Create notification for receiver (async, don't block)
    _createMessageNotification(senderId, receiverId, itemId, lastMessageText).catchError((error) {
      print('Error creating message notification: $error');
    });

    return message;
  }

  // Upload image and send image message
  Future<Message> sendImageMessage({
    required String senderId,
    required String receiverId,
    required String itemId,
    String text = '',
    required dynamic image, // File or XFile
  }) async {
    String imageUrl;
    
    try {
      // Upload image to Firebase Storage
      if (kIsWeb) {
        final xFile = image as XFile;
        imageUrl = await _uploadImageWeb(senderId, receiverId, itemId, xFile);
      } else {
        final xFile = image as XFile;
        final file = File(xFile.path);
        imageUrl = await _uploadImage(senderId, receiverId, itemId, file);
      }

      // Send message with image URL
      return await sendMessage(
        senderId: senderId,
        receiverId: receiverId,
        itemId: itemId,
        text: text,
        imageUrl: imageUrl,
      );
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  Future<String> _uploadImage(String senderId, String receiverId, String itemId, File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    final fileName = '${const Uuid().v4()}.$extension';
    final chatId = _getChatId(senderId, receiverId, itemId);
    final ref = _storage.ref().child('messages/$chatId/$fileName');

    // Get content type
    final contentType = _getContentType(extension);
    final metadata = SettableMetadata(contentType: contentType);

    final uploadTask = ref.putFile(file, metadata);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> _uploadImageWeb(String senderId, String receiverId, String itemId, XFile xFile) async {
    final bytesList = await xFile.readAsBytes();
    final bytes = Uint8List.fromList(bytesList);
    
    if (!_isValidImage(bytes)) {
      throw Exception('File is not a valid image');
    }

    final extension = _getExtensionFromName(xFile.name);
    final fileName = '${const Uuid().v4()}.$extension';
    final chatId = _getChatId(senderId, receiverId, itemId);
    final ref = _storage.ref().child('messages/$chatId/$fileName');

    final contentType = _getContentType(extension);
    final metadata = SettableMetadata(contentType: contentType);

    final uploadTask = ref.putData(bytes, metadata);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _getExtensionFromName(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return 'jpg';
  }

  bool _isValidImage(Uint8List bytes) {
    if (bytes.length < 4) return false;
    
    // Check for common image file signatures
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true;
    // WebP: RIFF...WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) return true;
    
    return false;
  }

  // Send a claim message
  Future<Message> sendClaimMessage({
    required String senderId,
    required String receiverId,
    required String itemId,
    required String claimId,
    required String text,
  }) async {
    final chatId = _getChatId(senderId, receiverId, itemId);
    final messagesRef = _firestore.collection('chats').doc(chatId).collection('messages');
    
    // Check if a claim message already exists for this claim
    final existingMessages = await messagesRef
        .where('claimId', isEqualTo: claimId)
        .where('type', isEqualTo: 'claim')
        .limit(1)
        .get();

    Message message;
    
    if (existingMessages.docs.isNotEmpty) {
      // Update existing claim message
      final existingDoc = existingMessages.docs.first;
      message = Message.fromMap(existingDoc.id, existingDoc.data());
      
      await existingDoc.reference.update({
        'text': text,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new claim message document
      final messageDoc = messagesRef.doc();
      message = Message(
        id: messageDoc.id,
        senderId: senderId,
        receiverId: receiverId,
        itemId: itemId,
        text: text,
        read: false,
        createdAt: DateTime.now(),
        type: MessageType.claim,
        claimId: claimId,
      );

      await messageDoc.set(message.toMap());

      // Create notification for receiver (async, don't block)
      _createClaimMessageNotification(senderId, receiverId, itemId, claimId).catchError((error) {
        print('Error creating claim message notification: $error');
      });
    }

    // Update chat metadata with claim message preview
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [senderId, receiverId],
      'itemId': itemId,
      'lastMessage': 'Claim the item',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return message;
  }

  // Update an existing claim message
  Future<void> updateClaimMessage({
    required String senderId,
    required String receiverId,
    required String itemId,
    required String claimId,
    required String text,
  }) async {
    final chatId = _getChatId(senderId, receiverId, itemId);
    final messagesRef = _firestore.collection('chats').doc(chatId).collection('messages');
    
    // Find the existing claim message
    final existingMessages = await messagesRef
        .where('claimId', isEqualTo: claimId)
        .where('type', isEqualTo: 'claim')
        .limit(1)
        .get();

    if (existingMessages.docs.isNotEmpty) {
      // Update existing claim message
      await existingMessages.docs.first.reference.update({
        'text': text,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update chat metadata
      await _firestore.collection('chats').doc(chatId).set({
        'lastMessage': 'Claim the item',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // Create notification for claim message
  Future<void> _createClaimMessageNotification(
    String senderId,
    String receiverId,
    String itemId,
    String claimId,
  ) async {
    try {
      // Check if user is authenticated before creating notification
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ User not authenticated - Cannot create claim message notification');
        return;
      }
      
      // Get sender info
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      String senderName = 'Someone';
      if (senderDoc.exists && senderDoc.data() != null) {
        final senderData = senderDoc.data()!;
        final firstName = senderData['firstName'] as String? ?? '';
        final lastName = senderData['lastName'] as String? ?? '';
        senderName = '$firstName $lastName'.trim();
        if (senderName.isEmpty) {
          final email = senderData['email'] as String? ?? '';
          if (email.isNotEmpty) {
            senderName = email.split('@').first;
          }
        }
      }

      // Get item info
      final itemDoc = await _firestore.collection('items').doc(itemId).get();
      final itemTitle = itemDoc.exists && itemDoc.data() != null
          ? itemDoc.data()!['title'] as String? ?? 'Item'
          : 'Item';

      // Create notification
      final notificationRef = _firestore
          .collection('notifications')
          .doc(receiverId)
          .collection('items')
          .doc(claimId); // Use claimId to avoid duplicates

      print('📝 Creating claim message notification for receiver $receiverId');
      print('   Current authenticated user: ${currentUser.uid}');

      await notificationRef.set({
        'title': 'New Claim Request',
        'body': '$senderName has claimed your item "$itemTitle"',
        'type': 'claim_request',
        'refId': claimId,
        'itemId': itemId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));
    } catch (e) {
      print('Error creating claim message notification: $e');
    }
  }

  // Mark messages as read
  Future<void> markAsRead(String userId1, String userId2, String itemId) async {
    final chatId = _getChatId(userId1, userId2, itemId);
    final messagesRef = _firestore.collection('chats').doc(chatId).collection('messages');
    
    // Get unread messages for this user
    final unreadMessages = await messagesRef
        .where('receiverId', isEqualTo: userId1)
        .where('read', isEqualTo: false)
        .get();

    // Mark all as read
    final batch = _firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // Get all chats for a user
  Stream<List<Map<String, dynamic>>> watchUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map(
      (snap) {
        final chats = snap.docs.map((doc) {
          final data = doc.data();
          return {
            'chatId': doc.id,
            'itemId': data['itemId'],
            'lastMessage': data['lastMessage'] ?? '',
            'lastMessageAt': (data['lastMessageAt'] as Timestamp?)?.toDate() ??
                (data['updatedAt'] as Timestamp?)?.toDate(),
            'lastMessageBy': data['lastMessageBy'],
            'participants': List<String>.from(data['participants'] ?? []),
          };
        }).toList();
        
        // Sort by lastMessageAt (fallback to updatedAt) descending
        chats.sort((a, b) {
          final aDate = a['lastMessageAt'] as DateTime?;
          final bDate = b['lastMessageAt'] as DateTime?;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        
        return chats;
      },
    );
  }

  // Create notification for new message
  Future<void> _createMessageNotification(
    String senderId,
    String receiverId,
    String itemId,
    String messageText,
  ) async {
    try {
      // Get sender info
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      String senderName = 'Someone';
      if (senderDoc.exists && senderDoc.data() != null) {
        final senderData = senderDoc.data()!;
        final firstName = senderData['firstName'] as String? ?? '';
        final lastName = senderData['lastName'] as String? ?? '';
        senderName = '$firstName $lastName'.trim();
        if (senderName.isEmpty) {
          final email = senderData['email'] as String? ?? '';
          if (email.isNotEmpty) {
            senderName = email.split('@').first;
          }
        }
      }

      // Get item info
      final itemDoc = await _firestore.collection('items').doc(itemId).get();
      final itemTitle = itemDoc.exists && itemDoc.data() != null
          ? itemDoc.data()!['title'] as String? ?? 'Item'
          : 'Item';

      // Create notification
      final notificationRef = _firestore
          .collection('notifications')
          .doc(receiverId)
          .collection('items')
          .doc();

      final previewText = messageText.length > 50 ? '${messageText.substring(0, 50)}...' : messageText;

      await notificationRef.set({
        'title': 'New Message',
        'body': '$senderName: $previewText',
        'type': 'message',
        'refId': senderId, // Store senderId for navigation
        'itemId': itemId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating message notification: $e');
    }
  }
}

