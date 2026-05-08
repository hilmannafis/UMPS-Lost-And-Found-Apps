import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/item.dart';
import '../services/color_extraction_service.dart';
import '../services/image_hash_service.dart';

class ItemRepository {
  ItemRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final _items = 'items';
  final ColorExtractionService _colorService = ColorExtractionService();
  final ImageHashService _hashService = ImageHashService();

  Stream<List<Item>> watchItems({ItemType? type, String? categoryId}) {
    Query<Map<String, dynamic>> query = _firestore.collection(_items);
    
    // Only show open items (not claimed, resolved, or rejected)
    // This ensures claimed items are removed from the main items list
    query = query.where('status', isEqualTo: 'open');
    
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    
    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }
    
    query = query.orderBy('createdAt', descending: true);
    
    return query.snapshots().map(
      (snap) {
        // Additional safety filter: filter out any items that might have been claimed
        // This is a client-side backup in case the query doesn't catch everything
        // Also filter out items that have claimedBy set (even if status wasn't updated correctly)
        return snap.docs
            .map((doc) => Item.fromMap(doc.id, doc.data()))
            .where((item) => 
              item.status == ItemStatus.open && 
              (item.claimedBy == null || item.claimedBy!.isEmpty)
            )
            .toList();
      },
    );
  }

  // Get all items for admin (including claimed, resolved, etc.)
  Stream<List<Item>> watchAllItemsForAdmin({ItemType? type}) {
    Query<Map<String, dynamic>> query = _firestore.collection(_items);
    
    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }
    
    query = query.orderBy('createdAt', descending: true);
    
    return query.snapshots().map(
      (snap) => snap.docs.map((doc) => Item.fromMap(doc.id, doc.data())).toList(),
    );
  }

  Stream<List<Item>> watchItemsByOwner(String ownerId, {ItemType? type}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_items)
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true);
    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map((doc) => Item.fromMap(doc.id, doc.data())).toList(),
    );
  }

  Stream<Item?> watchItem(String id) {
    return _firestore.collection(_items).doc(id).snapshots().map(
          (doc) => doc.exists && doc.data() != null ? Item.fromMap(doc.id, doc.data()!) : null,
        );
  }

  // Get items claimed by a specific user
  Stream<List<Item>> watchClaimedItemsByUser(String userId) {
    return _firestore
        .collection(_items)
        .where('claimedBy', isEqualTo: userId)
        .where('status', isEqualTo: 'claimed')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) => Item.fromMap(doc.id, doc.data())).toList(),
        );
  }

  Future<Item> create({
    required ItemType type,
    required String title,
    required String description,
    required String categoryId,
    required String ownerId,
    required String towerNumber,
    required String roomNumber,
    List<File> photos = const [],
    List<XFile>? photosWeb,
    String? contactNumber,
    DateTime? lostFoundDate,
    String? lostFoundTime,
  }) async {
    final doc = _firestore.collection(_items).doc();
    
    // Upload photos first (if any), then create item with photos
    List<String> photoUrls = [];
    if (kIsWeb && photosWeb != null && photosWeb.isNotEmpty) {
      try {
        print('📸 Starting photo upload for item ${doc.id} (${photosWeb.length} photos)');
        photoUrls = await _uploadPhotosWeb(doc.id, photosWeb);
        print('📸 Photo upload completed. Got ${photoUrls.length} URLs: $photoUrls');
      } catch (error) {
        print('⚠️ Photo upload failed (will create item without photos): $error');
        photoUrls = [];
      }
    } else if (!kIsWeb && photos.isNotEmpty) {
      try {
        print('📸 Starting photo upload for item ${doc.id} (${photos.length} photos)');
        photoUrls = await _uploadPhotos(doc.id, photos);
        print('📸 Photo upload completed. Got ${photoUrls.length} URLs: $photoUrls');
      } catch (error) {
        print('⚠️ Photo upload failed (will create item without photos): $error');
        photoUrls = [];
      }
    }

    // Extract image hash from first photo (if available) for perceptual image matching
    String? imageHash;
    if (photoUrls.isNotEmpty) {
      try {
        print('🔍 Generating image hash from first photo...');
        // Use the first photo for hash generation
        XFile? firstPhoto;
        if (kIsWeb && photosWeb != null && photosWeb.isNotEmpty) {
          firstPhoto = photosWeb[0];
        } else if (!kIsWeb && photos.isNotEmpty) {
          // Convert File to XFile for hash generation
          firstPhoto = XFile(photos[0].path);
        }
        
        if (firstPhoto != null) {
          imageHash = await _hashService.generateImageHash(firstPhoto);
          print('✅ Generated image hash: ${imageHash.substring(0, 16)}... (${imageHash.length} bits)');
        }
      } catch (e) {
        print('⚠️ Error generating image hash: $e (continuing without hash)');
      }
    }

    // Create item with photos (or without if upload failed)
    final item = Item(
      id: doc.id,
      type: type,
      title: title,
      description: description,
      categoryId: categoryId,
      ownerId: ownerId,
      photos: photoUrls, // Include photos from the start
      towerNumber: towerNumber,
      roomNumber: roomNumber,
      status: ItemStatus.open,
      contactNumber: contactNumber,
      lostFoundDate: lostFoundDate,
      lostFoundTime: lostFoundTime,
      createdAt: DateTime.now(),
      imageHash: imageHash, // Include extracted image hash
    );

    // Save item to Firestore with photos and image hash
    await doc.set(item.toMap());
    print('✅ Item created with ${photoUrls.length} photos${imageHash != null ? " and image hash" : ""}');
    
    return item;
  }

  Future<void> updateStatus({
    required String itemId,
    required ItemStatus status,
    String? verifiedBy,
  }) {
    return _firestore.collection(_items).doc(itemId).update({
      'status': status.name,
      'verifiedBy': verifiedBy,
      'verifiedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update({
    required String itemId,
    ItemType? type,
    String? title,
    String? description,
    String? categoryId,
    String? towerNumber,
    String? roomNumber,
    String? contactNumber,
    DateTime? lostFoundDate,
    String? lostFoundTime,
    List<String>? photos,
    List<File>? newPhotos,
    List<XFile>? newPhotosWeb,
  }) async {
    final updateData = <String, dynamic>{};
    
    if (type != null) updateData['type'] = type.name;
    if (title != null) updateData['title'] = title;
    if (description != null) updateData['description'] = description;
    if (categoryId != null) updateData['categoryId'] = categoryId;
    if (towerNumber != null) updateData['towerNumber'] = towerNumber;
    if (roomNumber != null) updateData['roomNumber'] = roomNumber;
    if (contactNumber != null) updateData['contactNumber'] = contactNumber;
    if (lostFoundDate != null) updateData['lostFoundDate'] = Timestamp.fromDate(lostFoundDate);
    if (lostFoundTime != null) updateData['lostFoundTime'] = lostFoundTime;
    
    // Handle photo updates
    List<String> finalPhotos = photos ?? [];
    
    // Upload new photos if provided
    if (kIsWeb && newPhotosWeb != null && newPhotosWeb.isNotEmpty) {
      try {
        final newPhotoUrls = await _uploadPhotosWeb(itemId, newPhotosWeb);
        finalPhotos.addAll(newPhotoUrls);
      } catch (e) {
        print('⚠️ Failed to upload new photos: $e');
      }
    } else if (!kIsWeb && newPhotos != null && newPhotos.isNotEmpty) {
      try {
        final newPhotoUrls = await _uploadPhotos(itemId, newPhotos);
        finalPhotos.addAll(newPhotoUrls);
      } catch (e) {
        print('⚠️ Failed to upload new photos: $e');
      }
    }
    
    if (photos != null || newPhotos != null || newPhotosWeb != null) {
      updateData['photos'] = finalPhotos;
    }
    
    return _firestore.collection(_items).doc(itemId).update(updateData);
  }

  Future<void> delete(String itemId) async {
    // Delete associated photos from storage
    try {
      final photosRef = _storage.ref().child('items/$itemId');
      final listResult = await photosRef.listAll();
      for (var item in listResult.items) {
        await item.delete();
      }
    } catch (e) {
      print('⚠️ Error deleting photos: $e');
      // Continue with item deletion even if photo deletion fails
    }
    
    // Delete the item document
    return _firestore.collection(_items).doc(itemId).delete();
  }

  Future<List<String>> _uploadPhotos(String itemId, List<File> photos) async {
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
        
        final ref = _storage.ref().child('items/$itemId/$fileName');
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

  Future<List<String>> _uploadPhotosWeb(String itemId, List<XFile> photos) async {
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
        
        print('📤 Uploading ${xFile.name} (${bytes.length} bytes, type: $contentType)');
        
        final ref = _storage.ref().child('items/$itemId/$fileName');
        final metadata = SettableMetadata(
          contentType: contentType,
        );
        uploads.add(
          ref.putData(bytes, metadata).then((task) async {
            final url = await task.ref.getDownloadURL();
            print('✅ Successfully uploaded ${xFile.name} -> $url');
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

