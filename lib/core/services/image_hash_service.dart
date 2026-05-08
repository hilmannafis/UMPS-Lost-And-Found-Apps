import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

/// Service for generating perceptual image hashes
/// Uses simple image hashing algorithm (pHash-like) for visual similarity matching
/// This is the EASIEST AI approach - no ML, no training, just simple hash comparison
class ImageHashService {
  /// Generate perceptual hash from an image
  /// Returns a binary string hash (e.g., "101011001010...")
  /// Similar images will have similar hashes
  Future<String> generateImageHash(XFile imageFile) async {
    try {
      Uint8List imageBytes;
      
      if (kIsWeb) {
        imageBytes = await imageFile.readAsBytes();
      } else {
        imageBytes = await File(imageFile.path).readAsBytes();
      }

      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Step 1: Resize to small size (8x8) for faster processing
      final resized = img.copyResize(image, width: 8, height: 8);
      
      // Step 2: Convert to grayscale
      final grayscale = img.grayscale(resized);
      
      // Step 3: Calculate average pixel value
      int sum = 0;
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          // Get pixel value - for grayscale, all channels are the same
          final pixel = grayscale.getPixel(x, y);
          // Get the red channel value (which equals grayscale value) and convert to int
          final luminance = pixel.r.toInt();
          sum += luminance;
        }
      }
      final average = sum ~/ 64; // 8x8 = 64 pixels
      
      // Step 4: Generate hash - compare each pixel to average
      final hash = StringBuffer();
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final pixel = grayscale.getPixel(x, y);
          // Get the red channel value (which equals grayscale value) and convert to int
          final luminance = pixel.r.toInt();
          // If pixel is brighter than average, set bit to 1, else 0
          hash.write(luminance > average ? '1' : '0');
        }
      }
      
      return hash.toString();
    } catch (e) {
      print('⚠️ Error generating image hash: $e');
      // Return a default hash (all zeros) if error
      return '0' * 64; // 8x8 = 64 bits
    }
  }

  /// Calculate Hamming distance between two hashes
  /// Returns the number of bits that differ
  /// Lower distance = more similar images
  /// Maximum distance is 64 (for 8x8 hash)
  int hammingDistance(String hash1, String hash2) {
    if (hash1.length != hash2.length) {
      return 64; // Maximum distance if lengths don't match
    }
    
    int distance = 0;
    for (int i = 0; i < hash1.length; i++) {
      if (hash1[i] != hash2[i]) {
        distance++;
      }
    }
    
    return distance;
  }

  /// Calculate similarity score between two hashes
  /// Returns a value between 0 (completely different) and 1 (identical)
  double calculateSimilarity(String hash1, String hash2) {
    final distance = hammingDistance(hash1, hash2);
    // Normalize to 0-1 range (0 = identical, 1 = completely different)
    // Then invert so 1 = identical, 0 = completely different
    return 1.0 - (distance / 64.0);
  }

  /// Check if two images are similar based on hash distance
  /// Returns true if Hamming distance is below threshold
  /// Threshold of 10 means images are similar if less than 10 bits differ
  bool isSimilar(String hash1, String hash2, {int threshold = 10}) {
    return hammingDistance(hash1, hash2) <= threshold;
  }
}

