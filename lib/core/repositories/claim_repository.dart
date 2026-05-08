import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/claim.dart';
import 'message_repository.dart';

class ClaimRepository {
  ClaimRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    MessageRepository? messageRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _messageRepository = messageRepository ?? MessageRepository(firestore: firestore);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final MessageRepository _messageRepository;
  final _claims = 'claims';

  Stream<List<Claim>> watchRecentClaims({int limit = 10}) {
    Query<Map<String, dynamic>> query = _firestore.collection(_claims).orderBy('createdAt', descending: true);
    if (limit > 0) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snap) => snap.docs.map((doc) => Claim.fromMap(doc.id, doc.data())).toList());
  }

  Stream<List<Claim>> watchAllClaims() {
    return _firestore
        .collection(_claims)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Claim.fromMap(doc.id, doc.data())).toList());
  }

  Stream<List<Claim>> watchClaimsByUser(String userId) {
    return _firestore
        .collection(_claims)
        .where('claimantId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Claim.fromMap(doc.id, doc.data())).toList());
  }

  Stream<List<Claim>> watchClaimsForItem(String itemId) {
    return _firestore
        .collection(_claims)
        .where('itemId', isEqualTo: itemId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Claim.fromMap(doc.id, doc.data())).toList());
  }

  Stream<Claim?> watchClaim(String claimId) {
    return _firestore
        .collection(_claims)
        .doc(claimId)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null ? Claim.fromMap(doc.id, doc.data()!) : null);
  }

  // Get claims for items owned by a user
  Future<List<Claim>> getClaimsForOwnerItems(String ownerId) async {
    // First get all item IDs owned by this user
    final itemsSnapshot = await _firestore
        .collection('items')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    
    if (itemsSnapshot.docs.isEmpty) return [];
    
    final itemIds = itemsSnapshot.docs.map((doc) => doc.id).toList();
    
    // Get all claims for these items
    final claimsSnapshot = await _firestore
        .collection(_claims)
        .where('itemId', whereIn: itemIds.length > 10 ? itemIds.take(10).toList() : itemIds)
        .orderBy('createdAt', descending: true)
        .get();
    
    return claimsSnapshot.docs.map((doc) => Claim.fromMap(doc.id, doc.data())).toList();
  }

  Stream<List<Claim>> watchClaimsForOwnerItems(String ownerId) {
    // This is a simplified version - for production, you might want to use a more efficient approach
    return _firestore
        .collection(_claims)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      // Filter claims where the item is owned by this user
      return snap.docs.map((doc) {
        final claim = Claim.fromMap(doc.id, doc.data());
        return claim;
      }).toList();
    });
  }

  Future<Claim> create({
    required String itemId,
    required String claimantId,
    required String message,
    List<File> evidencePhotos = const [],
    List<XFile>? evidencePhotosWeb,
  }) async {
    final doc = _firestore.collection(_claims).doc();
    
    // Upload evidence photos first (if any), then create claim with photos
    List<String> evidenceUrls = [];
    if (kIsWeb && evidencePhotosWeb != null && evidencePhotosWeb.isNotEmpty) {
      try {
        print('📸 Starting evidence photo upload for claim ${doc.id} (${evidencePhotosWeb.length} photos)');
        evidenceUrls = await _uploadEvidenceWeb(doc.id, evidencePhotosWeb);
        print('📸 Evidence photo upload completed. Got ${evidenceUrls.length} URLs: $evidenceUrls');
      } catch (error) {
        print('⚠️ Evidence photo upload failed (will create claim without photos): $error');
        evidenceUrls = [];
      }
    } else if (!kIsWeb && evidencePhotos.isNotEmpty) {
      try {
        print('📸 Starting evidence photo upload for claim ${doc.id} (${evidencePhotos.length} photos)');
        evidenceUrls = await _uploadEvidence(doc.id, evidencePhotos);
        print('📸 Evidence photo upload completed. Got ${evidenceUrls.length} URLs: $evidenceUrls');
      } catch (error) {
        print('⚠️ Evidence photo upload failed (will create claim without photos): $error');
        evidenceUrls = [];
      }
    }

    // Create claim document with photos (or without if upload failed)
    final claim = Claim(
      id: doc.id,
      itemId: itemId,
      claimantId: claimantId,
      message: message,
      evidencePhotos: evidenceUrls, // Include photos from the start
      status: ClaimStatus.pending,
      createdAt: DateTime.now(),
    );
    await doc.set(claim.toMap());
    print('✅ Claim created with ${evidenceUrls.length} evidence photos');
    
    // Get item owner ID to create message
    final itemDoc = await _firestore.collection('items').doc(itemId).get();
    final ownerId = itemDoc.exists && itemDoc.data() != null
        ? itemDoc.data()!['ownerId'] as String?
        : null;
    
    // Create claim message in chat (async, don't block)
    if (ownerId != null && ownerId != claimantId) {
      _messageRepository.sendClaimMessage(
        senderId: claimantId,
        receiverId: ownerId,
        itemId: itemId,
        claimId: doc.id,
        text: 'Claim the item',
      ).then((_) {
        print('✅ Claim message created successfully in chat');
      }).catchError((error) {
        print('❌ Error creating claim message: $error');
      });
    }
    
    // Create notification asynchronously (fire and forget, optimized - doesn't block)
    // Use unawaited to ensure it runs but doesn't block
    _createClaimNotificationOptimized(doc.id, itemId, claimantId).then((_) {
      print('✅ Notification created successfully for claim ${doc.id}');
    }).catchError((error, stackTrace) {
      // Log error but don't fail the claim creation
      print('❌ Error creating notification: $error');
      print('Stack trace: $stackTrace');
    });
    
    // Return claim with photos included
    return claim;
  }

  // Optimized version: fetch item and claimant in parallel
  Future<void> _createClaimNotificationOptimized(
    String claimId,
    String itemId,
    String claimantId,
  ) async {
    try {
      // Check if user is authenticated before creating notification
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ User not authenticated - Cannot create notification');
        return;
      }
      
      print('🔔 Starting notification creation for claim $claimId, item $itemId, claimant $claimantId');
      
      // Fetch item and claimant info in parallel
      final itemFuture = _firestore.collection('items').doc(itemId).get();
      final claimantFuture = _firestore.collection('users').doc(claimantId).get();
      
      final results = await Future.wait([itemFuture, claimantFuture]);
      final itemDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final claimantDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      
      if (!itemDoc.exists) {
        print('❌ Item not found: $itemId - Cannot create notification');
        return;
      }

      final itemData = itemDoc.data()!;
      final ownerId = itemData['ownerId'] as String?;
      if (ownerId == null || ownerId.isEmpty) {
        print('❌ Item ownerId is null or empty - Cannot create notification');
        return;
      }

      final itemTitle = itemData['title'] as String? ?? 'Item';
      
      // Get claimant name
      String claimantName = 'Someone';
      if (claimantDoc.exists && claimantDoc.data() != null) {
        final claimantData = claimantDoc.data()!;
        final firstName = claimantData['firstName'] as String? ?? '';
        final lastName = claimantData['lastName'] as String? ?? '';
        claimantName = '$firstName $lastName'.trim();
        if (claimantName.isEmpty) {
          // Fallback to email username if name is empty
          final email = claimantData['email'] as String? ?? '';
          if (email.isNotEmpty) {
            claimantName = email.split('@').first;
          }
        }
      }
      
      // Create notification for item owner
      // Use claimId as document ID to ensure uniqueness and avoid duplicates
      final notificationRef = _firestore
          .collection('notifications')
          .doc(ownerId)
          .collection('items')
          .doc(claimId); // Use claimId as document ID
      
      final notificationData = {
        'title': 'New Claim Request',
        'body': '$claimantName has claimed your item "$itemTitle"',
        'type': 'claim_request',
        'refId': claimId,
        'itemId': itemId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      print('📝 Creating notification for owner $ownerId');
      print('   Notification data: $notificationData');
      print('   Current authenticated user: ${currentUser.uid}');
      
      await notificationRef.set(notificationData, SetOptions(merge: false));
      
      // Verify notification was created
      final verifyDoc = await notificationRef.get();
      if (verifyDoc.exists) {
        print('✅ Notification successfully created and verified in Firestore for owner $ownerId');
      } else {
        print('⚠️ Warning: Notification document not found after creation - may be a permissions issue');
      }
    } catch (e, stackTrace) {
      print('❌ Error in _createClaimNotificationOptimized: $e');
      print('   Stack trace: $stackTrace');
      // Don't rethrow - just log the error to prevent breaking the claim creation
    }
  }
  
  // Keep old method for backward compatibility (if needed)
  Future<void> _createClaimNotification(
    String claimId,
    String itemId,
    String claimantId,
  ) async {
    return _createClaimNotificationOptimized(claimId, itemId, claimantId);
  }

  Future<void> decide({
    required String claimId,
    required ClaimStatus status,
    required String decidedBy,
    String? meetLocation,
    DateTime? meetTime,
  }) async {
    // Get claim info
    final claimDoc = await _firestore.collection(_claims).doc(claimId).get();
    if (!claimDoc.exists) return;
    
    final claimData = claimDoc.data()!;
    final claimantId = claimData['claimantId'] as String;
    final itemId = claimData['itemId'] as String;
    
    // Update claim status with meet information
    final updateData = <String, dynamic>{
      'status': status.name,
      'decidedBy': decidedBy,
      'decidedAt': FieldValue.serverTimestamp(),
    };
    
    // Add meet information if provided (only for approved claims)
    if (status == ClaimStatus.approved) {
      if (meetLocation != null && meetLocation.isNotEmpty) {
        updateData['meetLocation'] = meetLocation;
      }
      if (meetTime != null) {
        updateData['meetTime'] = Timestamp.fromDate(meetTime);
      }
    }
    
    await _firestore.collection(_claims).doc(claimId).update(updateData);
    
    // If claim is approved, update item status to claimed
    if (status == ClaimStatus.approved) {
      try {
        await _firestore.collection('items').doc(itemId).update({
          'status': 'claimed',
          'claimedBy': claimantId,
        });
        print('✅ Item $itemId status updated to claimed by $claimantId');
      } catch (e) {
        print('❌ Error updating item status: $e');
        rethrow; // Re-throw to ensure the error is visible
      }
    }
    
    // Get item info
    final itemDoc = await _firestore.collection('items').doc(itemId).get();
    final itemTitle = itemDoc.exists && itemDoc.data() != null
        ? itemDoc.data()!['title'] as String? ?? 'Item'
        : 'Item';
    
    // Check if user is authenticated before creating notification
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ User not authenticated - Cannot create claim response notification');
      return;
    }
    
    // Get owner info
    final ownerDoc = await _firestore.collection('users').doc(decidedBy).get();
    final ownerName = ownerDoc.exists && ownerDoc.data() != null
        ? '${ownerDoc.data()!['firstName'] ?? ''} ${ownerDoc.data()!['lastName'] ?? ''}'.trim()
        : 'Owner';
    
    // Create notification for claimant
    final notificationRef = _firestore
        .collection('notifications')
        .doc(claimantId)
        .collection('items')
        .doc();
    
    final statusText = status == ClaimStatus.approved ? 'approved' : 'rejected';
    final statusTitle = status == ClaimStatus.approved ? 'Approved' : 'Rejected';
    
    // Build notification body with meet information if approved
    String notificationBody = 'Your claim for "$itemTitle" has been $statusText by $ownerName';
    if (status == ClaimStatus.approved && meetLocation != null && meetTime != null) {
      final dateFormat = DateFormat('MMM dd, yyyy');
      final timeFormat = DateFormat('hh:mm a');
      notificationBody += '\n\n📍 Meet Location: $meetLocation\n🕐 Meet Time: ${dateFormat.format(meetTime)} at ${timeFormat.format(meetTime)}';
    }
    
    print('📝 Creating claim response notification for claimant $claimantId');
    print('   Current authenticated user: ${currentUser.uid}');
    
    await notificationRef.set({
      'title': 'Claim $statusTitle',
      'body': notificationBody,
      'type': 'claim_response',
      'refId': claimId,
      'itemId': itemId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'meetLocation': meetLocation,
      'meetTime': meetTime != null ? Timestamp.fromDate(meetTime) : null,
    });
    
    // Update the existing claim message with status and meeting details (if approved)
    try {
      String claimMessageText = 'Claim the item';
      
      if (status == ClaimStatus.approved) {
        if (meetLocation != null && meetTime != null) {
          final dateFormat = DateFormat('MMM dd, yyyy');
          final timeFormat = DateFormat('hh:mm a');
          final formattedDate = dateFormat.format(meetTime);
          final formattedTime = timeFormat.format(meetTime);
          
          // Create combined message with status and meet details
          claimMessageText = '✅ Claim Approved\n'
              'Your claim has been approved!\n\n'
              '📍 Meet Location: $meetLocation\n'
              '🕐 Meet Date: $formattedDate\n'
              '⏰ Meet Time: $formattedTime\n\n'
              'Please arrive on time to collect your item.';
        } else {
          claimMessageText = '✅ Claim Approved\nYour claim has been approved!';
        }
      } else if (status == ClaimStatus.rejected) {
        claimMessageText = '❌ Claim Rejected\nYour claim has been rejected.';
      }
      
      // Update existing claim message (use original sender/receiver from when claim was created)
      // The message was sent from claimantId to ownerId
      final itemDoc = await _firestore.collection('items').doc(itemId).get();
      final ownerId = itemDoc.exists && itemDoc.data() != null
          ? itemDoc.data()!['ownerId'] as String? ?? ''
          : '';
      
      if (ownerId.isNotEmpty) {
        await _messageRepository.updateClaimMessage(
          senderId: claimantId, // Original sender (claimant)
          receiverId: ownerId, // Original receiver (owner)
          itemId: itemId,
          claimId: claimId,
          text: claimMessageText,
        );
        print('✅ Claim message updated successfully');
      }
    } catch (e) {
      print('⚠️ Error updating claim message: $e');
      // Don't throw - notification was already sent, message update is optional
    }
  }

  Future<List<String>> _uploadEvidence(String claimId, List<File> photos) async {
    if (photos.isEmpty) return [];
    
    final uploads = <Future<String>>[];
    
    for (final file in photos) {
      if (!file.existsSync()) {
        print('⚠️ File does not exist, skipping: ${file.path}');
        continue;
      }
      
      try {
        // Detect file extension and content type from file path
        final extension = file.path.split('.').last.toLowerCase();
        final contentType = _getContentType(extension);
        final fileName = '${const Uuid().v4()}.$extension';
        
        final ref = _storage.ref().child('claims/$claimId/$fileName');
        final metadata = SettableMetadata(
          contentType: contentType,
        );
        uploads.add(
          ref.putFile(file, metadata).then((task) => task.ref.getDownloadURL()).catchError((e) {
            print('⚠️ Failed to upload ${file.path}: $e');
            return ''; // Return empty string instead of throwing
          }),
        );
      } catch (e) {
        print('⚠️ Error preparing upload for ${file.path}: $e');
        // Continue with other files
      }
    }
    
    if (uploads.isEmpty) {
      print('⚠️ No valid photos to upload');
      return [];
    }
    
    try {
      final urls = await Future.wait(uploads);
      // Filter out empty strings (failed uploads) and return only successful URLs
      final successfulUrls = urls.where((url) => url.isNotEmpty).toList();
      if (successfulUrls.length < urls.length) {
        print('⚠️ Some photos failed to upload (${urls.length - successfulUrls.length} failed, ${successfulUrls.length} succeeded)');
      }
      return successfulUrls;
    } catch (e) {
      // Even if all uploads fail, return empty list instead of throwing
      print('⚠️ All photo uploads failed: $e');
      return [];
    }
  }

  Future<List<String>> _uploadEvidenceWeb(String claimId, List<XFile> photos) async {
    if (photos.isEmpty) return [];
    
    final uploads = <Future<String>>[];
    
    for (final xFile in photos) {
      try {
        // Read bytes and convert to Uint8List
        final bytesList = await xFile.readAsBytes();
        if (bytesList.isEmpty) {
          print('⚠️ File is empty, skipping: ${xFile.name}');
          continue;
        }
        
        // Convert List<int> to Uint8List
        final bytes = Uint8List.fromList(bytesList);
        
        // Validate image by checking magic bytes (file signature)
        if (!_isValidImage(bytes)) {
          print('⚠️ File is not a valid image, skipping: ${xFile.name}');
          continue;
        }
        
        // Detect file extension and content type from file name or mime type
        final extension = _getExtensionFromName(xFile.name);
        final contentType = _getContentType(extension);
        final fileName = '${const Uuid().v4()}.$extension';
        
        print('📤 Uploading evidence ${xFile.name} (${bytes.length} bytes, type: $contentType)');
        
        final ref = _storage.ref().child('claims/$claimId/$fileName');
        final metadata = SettableMetadata(
          contentType: contentType,
        );
        uploads.add(
          ref.putData(bytes, metadata).then((task) async {
            final url = await task.ref.getDownloadURL();
            print('✅ Successfully uploaded evidence ${xFile.name} -> $url');
            return url;
          }).catchError((e) {
            print('⚠️ Failed to upload ${xFile.name}: $e');
            return ''; // Return empty string instead of throwing
          }),
        );
      } catch (e, stackTrace) {
        print('⚠️ Error preparing upload for ${xFile.name}: $e');
        print('   Stack trace: $stackTrace');
        // Continue with other files
      }
    }
    
    if (uploads.isEmpty) {
      print('⚠️ No valid photos to upload');
      return [];
    }
    
    try {
      final urls = await Future.wait(uploads);
      // Filter out empty strings (failed uploads) and return only successful URLs
      final successfulUrls = urls.where((url) => url.isNotEmpty).toList();
      if (successfulUrls.length < urls.length) {
        print('⚠️ Some photos failed to upload (${urls.length - successfulUrls.length} failed, ${successfulUrls.length} succeeded)');
      }
      return successfulUrls;
    } catch (e) {
      // Even if all uploads fail, return empty list instead of throwing
      print('⚠️ All photo uploads failed: $e');
      return [];
    }
  }

  // Helper method to get content type from file extension
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
        return 'image/jpeg'; // Default to JPEG
    }
  }

  // Helper method to get extension from file name
  String _getExtensionFromName(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return 'jpg'; // Default to jpg if no extension
  }

  // Validate image by checking magic bytes (file signatures)
  bool _isValidImage(Uint8List bytes) {
    if (bytes.length < 4) return false;
    
    // Check for JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }
    
    // Check for PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return true;
    }
    
    // Check for GIF: 47 49 46 38
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
      return true;
    }
    
    // Check for WebP: RIFF...WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return true;
    }
    
    return false;
  }
}

