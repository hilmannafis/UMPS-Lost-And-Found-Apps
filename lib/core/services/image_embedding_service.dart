import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Service for generating image embeddings using CLIP model via API
/// This enables visual similarity search - finding items that look similar to a query image
/// 
/// Setup Options:
/// 1. Use Hugging Face Inference API (free tier available)
/// 2. Use OpenAI CLIP API
/// 3. Host your own CLIP model via Firebase Functions or custom backend
/// 4. Use a vector database service (Pinecone, Weaviate, etc.)
class ImageEmbeddingService {
  // Option 1: Hugging Face Inference API (set your API key)
  // static const String _apiUrl = 'https://api-inference.huggingface.co/models/sentence-transformers/clip-ViT-B-32';
  // static const String? _apiKey = 'YOUR_HUGGING_FACE_API_KEY';
  
  // Option 2: Custom backend API endpoint (recommended for production)
  // Set this to your Firebase Function or custom API endpoint
  static const String? _apiUrl = null; // e.g., 'https://your-project.cloudfunctions.net/generateEmbedding'
  static const String? _apiKey = null;
  
  // For now, return null to use label-based search as fallback
  // To enable embeddings, set up one of the options above
  
  /// Generate embedding vector for an image
  /// Returns a list of floats (embedding vector) or null if failed
  Future<List<double>?> generateEmbedding(XFile imageFile) async {
    try {
      if (kIsWeb) {
        // For web, read bytes from XFile
        final bytes = await imageFile.readAsBytes();
        return await _generateEmbeddingFromBytes(bytes);
      } else {
        // For mobile, read file
        final file = File(imageFile.path);
        if (!file.existsSync()) {
          print('❌ Image file does not exist: ${imageFile.path}');
          return null;
        }
        final bytes = await file.readAsBytes();
        return await _generateEmbeddingFromBytes(bytes);
      }
    } catch (e) {
      print('❌ Error generating embedding: $e');
      return null;
    }
  }
  
  /// Generate embedding from image bytes
  Future<List<double>?> _generateEmbeddingFromBytes(Uint8List imageBytes) async {
    // If API URL is not configured, return null to use label-based search
    if (_apiUrl == null || _apiUrl!.isEmpty) {
      print('⚠️ Embedding API not configured. Using label-based search as fallback.');
      print('   To enable vector similarity search, configure _apiUrl in ImageEmbeddingService');
      return null;
    }
    
    try {
      // Convert image to base64
      final base64Image = base64Encode(imageBytes);
      
      // Prepare request
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (_apiKey != null && _apiKey!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_apiKey';
      }
      
      // Format depends on your API - adjust as needed
      final body = jsonEncode({
        'image': base64Image,
        // Or for Hugging Face: {'inputs': {'image': base64Image}}
      });
      
      // Call embedding API
      final response = await http.post(
        Uri.parse(_apiUrl!),
        headers: headers,
        body: body,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Embedding generation timeout');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Handle different response formats
        List<double>? embedding;
        
        if (data is List) {
          embedding = (data as List).map((e) => (e as num).toDouble()).toList();
        } else if (data is Map && data.containsKey('embedding')) {
          embedding = (data['embedding'] as List).map((e) => (e as num).toDouble()).toList();
        } else if (data is Map && data.containsKey('data')) {
          embedding = (data['data'] as List).map((e) => (e as num).toDouble()).toList();
        }
        
        if (embedding != null && embedding.isNotEmpty) {
          print('✅ Generated embedding with ${embedding.length} dimensions');
          return embedding;
        }
      } else {
        print('❌ Embedding API error: ${response.statusCode} - ${response.body}');
        if (response.statusCode == 401) {
          print('⚠️ API key may be required. Set _apiKey in ImageEmbeddingService');
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error calling embedding API: $e');
      return null;
    }
  }
  
  /// Calculate cosine similarity between two embeddings
  /// Returns a value between -1 and 1, where 1 is most similar
  double cosineSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw ArgumentError('Embeddings must have the same length');
    }
    
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }
    
    final denominator = (norm1 * norm2);
    if (denominator == 0.0) return 0.0;
    
    return dotProduct / denominator;
  }
  
  /// Generate embedding from image URL (for existing items)
  Future<List<double>?> generateEmbeddingFromUrl(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        return await _generateEmbeddingFromBytes(bytes);
      }
      return null;
    } catch (e) {
      print('❌ Error generating embedding from URL: $e');
      return null;
    }
  }
}

