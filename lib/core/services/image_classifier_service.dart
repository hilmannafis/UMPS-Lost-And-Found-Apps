import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';

/// Service for classifying images using Google ML Kit
/// Maps detected labels to app categories
/// Note: ML Kit Image Labeling works on mobile platforms (iOS/Android) only
class ImageClassifierService {
  final ImageLabeler? _labeler;

  ImageClassifierService()
      : _labeler = kIsWeb ? null : ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.5),
        );

  /// Maps ML Kit labels to app category IDs
  final Map<String, String> _labelToCategory = {
    // Electronics
    'phone': 'electronics',
    'smartphone': 'electronics',
    'mobile phone': 'electronics',
    'tablet': 'electronics',
    'laptop': 'electronics',
    'computer': 'electronics',
    'headphones': 'electronics',
    'earphones': 'electronics',
    'earbuds': 'electronics',
    'watch': 'electronics',
    'smartwatch': 'electronics',
    'camera': 'electronics',
    'electronic device': 'electronics',
    'gadget': 'electronics',
    'device': 'electronics',
    'charger': 'electronics',
    'power bank': 'electronics',
    'keyboard': 'electronics',
    'mouse': 'electronics',
    
    // Clothing
    'clothing': 'clothing',
    'shirt': 'clothing',
    't-shirt': 'clothing',
    'pants': 'clothing',
    'jeans': 'clothing',
    'dress': 'clothing',
    'jacket': 'clothing',
    'coat': 'clothing',
    'sweater': 'clothing',
    'hoodie': 'clothing',
    'shoes': 'clothing',
    'sneakers': 'clothing',
    'boots': 'clothing',
    'sandals': 'clothing',
    'hat': 'clothing',
    'cap': 'clothing',
    'gloves': 'clothing',
    
    // Accessories
    'wallet': 'accessories',
    'purse': 'accessories',
    'handbag': 'accessories',
    'sunglasses': 'accessories',
    'glasses': 'accessories',
    'jewelry': 'accessories',
    'necklace': 'accessories',
    'bracelet': 'accessories',
    'ring': 'accessories',
    'watch': 'accessories',
    'belt': 'accessories',
    
    // Bags
    'bag': 'bags',
    'backpack': 'bags',
    'handbag': 'bags',
    'suitcase': 'bags',
    'luggage': 'bags',
    'briefcase': 'bags',
    'tote bag': 'bags',
    'messenger bag': 'bags',
    
    // Documents
    'document': 'documents',
    'paper': 'documents',
    'book': 'documents',
    'notebook': 'documents',
    'folder': 'documents',
    'envelope': 'documents',
    'id card': 'documents',
    'credit card': 'documents',
    'driver license': 'documents',
    'passport': 'documents',
    
    // Books
    'book': 'books',
    'textbook': 'books',
    'notebook': 'books',
    'diary': 'books',
    'journal': 'books',
  };

  /// Classify an image and return suggested category
  /// Returns the category ID that best matches the image, or null if no match
  Future<String?> classifyImage(XFile imageFile) async {
    // ML Kit doesn't support web platform
    if (kIsWeb || _labeler == null) {
      return null;
    }

    try {
      // For mobile, use file path
      final file = File(imageFile.path);
      if (!file.existsSync()) {
        return null;
      }
      final inputImage = InputImage.fromFilePath(imageFile.path);

      final List<ImageLabel> labels = await _labeler!.processImage(inputImage);
      
      if (labels.isEmpty) {
        return null;
      }

      // Score each category based on label matches
      final Map<String, double> categoryScores = {};
      
      for (final label in labels) {
        final labelText = label.label.toLowerCase();
        final confidence = label.confidence;
        
        // Check for direct matches
        if (_labelToCategory.containsKey(labelText)) {
          final category = _labelToCategory[labelText]!;
          categoryScores[category] = (categoryScores[category] ?? 0.0) + confidence;
        }
        
        // Check for partial matches (e.g., "mobile phone" contains "phone")
        for (final entry in _labelToCategory.entries) {
          if (labelText.contains(entry.key) || entry.key.contains(labelText)) {
            final category = entry.value;
            categoryScores[category] = (categoryScores[category] ?? 0.0) + (confidence * 0.7);
          }
        }
      }

      if (categoryScores.isEmpty) {
        return null;
      }

      // Return category with highest score
      final bestCategory = categoryScores.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      
      // Only return if confidence is reasonable
      if (bestCategory.value >= 0.3) {
        return bestCategory.key;
      }

      return null;
    } catch (e) {
      // Handle MissingPluginException gracefully
      if (e.toString().contains('MissingPluginException') || 
          e.toString().contains('No implementation found')) {
        print('⚠️ ML Kit plugin not available. Please rebuild the app after adding the dependency.');
        print('   Run: flutter clean && flutter pub get && flutter run');
        return null;
      }
      print('Error classifying image: $e');
      return null;
    }
  }

  /// Classify multiple images and return the most common category
  Future<String?> classifyImages(List<XFile> imageFiles) async {
    if (imageFiles.isEmpty) {
      return null;
    }

    final Map<String, int> categoryCounts = {};
    
    for (final imageFile in imageFiles) {
      final category = await classifyImage(imageFile);
      if (category != null) {
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }
    }

    if (categoryCounts.isEmpty) {
      return null;
    }

    // Return the most frequently detected category
    return categoryCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Get all detected labels from an image (for similarity search)
  /// Returns a list of label strings with their confidence scores
  Future<List<Map<String, dynamic>>> getAllLabels(XFile imageFile) async {
    // ML Kit doesn't support web platform
    if (kIsWeb || _labeler == null) {
      return [];
    }

    try {
      final file = File(imageFile.path);
      if (!file.existsSync()) {
        return [];
      }
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final List<ImageLabel> labels = await _labeler!.processImage(inputImage);
      
      // Return labels with confidence scores, sorted by confidence
      return labels
          .map((label) => {
                'label': label.label,
                'confidence': label.confidence,
              })
          .toList()
        ..sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
    } catch (e) {
      print('Error getting labels: $e');
      return [];
    }
  }

  /// Extract color and design attributes from detected labels
  /// Returns a map with itemType, colors, and design attributes
  Map<String, dynamic> extractAttributes(List<Map<String, dynamic>> labels) {
    final itemTypes = <String>[];
    final colors = <String>[];
    final designAttributes = <String>[];
    
    // Color keywords that might appear in labels
    final colorKeywords = [
      'red', 'blue', 'green', 'yellow', 'orange', 'purple', 'pink', 'black', 'white', 'gray', 'grey',
      'brown', 'beige', 'tan', 'navy', 'maroon', 'teal', 'cyan', 'magenta', 'gold', 'silver', 'bronze'
    ];
    
    // Design/pattern keywords
    final designKeywords = [
      'striped', 'polka dot', 'dot', 'pattern', 'solid', 'plain', 'textured', 'smooth', 'glossy', 'matte',
      'leather', 'fabric', 'metal', 'plastic', 'wood', 'glass', 'rubber', 'silicone'
    ];
    
    for (final labelData in labels) {
      final label = (labelData['label'] as String).toLowerCase();
      
      // Check for item types (exclude colors and design words)
      if (!colorKeywords.any((c) => label.contains(c)) && 
          !designKeywords.any((d) => label.contains(d))) {
        // This is likely an item type
        itemTypes.add(label);
      }
      
      // Check for colors
      for (final color in colorKeywords) {
        if (label.contains(color)) {
          colors.add(color);
        }
      }
      
      // Check for design attributes
      for (final design in designKeywords) {
        if (label.contains(design)) {
          designAttributes.add(design);
        }
      }
    }
    
    return {
      'itemTypes': itemTypes.toSet().toList(), // Remove duplicates
      'colors': colors.toSet().toList(),
      'designAttributes': designAttributes.toSet().toList(),
    };
  }

  void dispose() {
    _labeler?.close();
  }
}

