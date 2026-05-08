import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palette_generator/palette_generator.dart';

/// Service to extract dominant colors from images for similarity matching
class ColorExtractionService {
  /// Extract dominant colors from an image
  /// Returns a list of Color objects representing the most prominent colors
  Future<List<Color>> extractDominantColors(XFile imageFile) async {
    try {
      Uint8List imageBytes;
      
      if (kIsWeb) {
        imageBytes = await imageFile.readAsBytes();
      } else {
        imageBytes = await File(imageFile.path).readAsBytes();
      }

      ImageProvider imageProvider;
      if (kIsWeb) {
        imageProvider = MemoryImage(imageBytes);
      } else {
        imageProvider = FileImage(File(imageFile.path));
      }

      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider as ImageProvider<Object>,
        maximumColorCount: 5, // Get top 5 dominant colors
      );

      final colors = <Color>[];
      
      // Add dominant color (most prominent)
      if (paletteGenerator.dominantColor != null) {
        colors.add(paletteGenerator.dominantColor!.color);
      }
      
      // Add vibrant colors
      if (paletteGenerator.vibrantColor != null) {
        colors.add(paletteGenerator.vibrantColor!.color);
      }
      
      if (paletteGenerator.mutedColor != null) {
        colors.add(paletteGenerator.mutedColor!.color);
      }
      
      // Add other prominent colors from the palette
      // Note: paletteGenerator.colors returns List<Color> directly
      for (final color in paletteGenerator.colors) {
        if (!colors.contains(color)) {
          colors.add(color);
        }
        if (colors.length >= 5) break; // Limit to 5 colors
      }

      return colors.isEmpty ? [Colors.grey] : colors;
    } catch (e) {
      print('⚠️ Error extracting colors: $e');
      return [Colors.grey]; // Return grey as fallback
    }
  }

  /// Extract dominant colors from image bytes (for web)
  Future<List<Color>> extractDominantColorsFromBytes(Uint8List imageBytes) async {
    try {
      final imageProvider = MemoryImage(imageBytes);
      
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 5,
      );

      final colors = <Color>[];
      
      if (paletteGenerator.dominantColor != null) {
        colors.add(paletteGenerator.dominantColor!.color);
      }
      
      if (paletteGenerator.vibrantColor != null) {
        colors.add(paletteGenerator.vibrantColor!.color);
      }
      
      if (paletteGenerator.mutedColor != null) {
        colors.add(paletteGenerator.mutedColor!.color);
      }
      
      // Note: paletteGenerator.colors returns List<Color> directly
      for (final color in paletteGenerator.colors) {
        if (!colors.contains(color)) {
          colors.add(color);
        }
        if (colors.length >= 5) break;
      }

      return colors.isEmpty ? [Colors.grey] : colors;
    } catch (e) {
      print('⚠️ Error extracting colors from bytes: $e');
      return [Colors.grey];
    }
  }

  /// Convert Color to RGB values for storage
  Map<String, int> colorToRgb(Color color) {
    return {
      'r': color.red,
      'g': color.green,
      'b': color.blue,
    };
  }

  /// Convert RGB map back to Color
  Color rgbToColor(Map<String, int> rgb) {
    return Color.fromRGBO(rgb['r']!, rgb['g']!, rgb['b']!, 1.0);
  }

  /// Calculate color similarity between two colors using Euclidean distance in RGB space
  /// Returns a value between 0 (identical) and 1 (completely different)
  double colorSimilarity(Color color1, Color color2) {
    final rDiff = (color1.red - color2.red).abs();
    final gDiff = (color1.green - color2.green).abs();
    final bDiff = (color1.blue - color2.blue).abs();
    
    // Maximum possible difference (255 * 3)
    final maxDiff = 255.0 * 3.0;
    final totalDiff = rDiff + gDiff + bDiff;
    
    // Normalize to 0-1 range (0 = identical, 1 = completely different)
    return totalDiff / maxDiff;
  }

  /// Calculate overall similarity between two sets of colors
  /// Returns a score between 0 (no match) and 1 (perfect match)
  double calculateColorSimilarityScore(List<Color> colors1, List<Color> colors2) {
    if (colors1.isEmpty || colors2.isEmpty) return 0.0;
    
    // Compare dominant colors (first in list)
    final dominantSimilarity = 1.0 - colorSimilarity(colors1[0], colors2[0]);
    
    // Compare all colors and find best matches
    double totalSimilarity = 0.0;
    int matches = 0;
    
    for (final color1 in colors1) {
      double bestMatch = 0.0;
      for (final color2 in colors2) {
        final similarity = 1.0 - colorSimilarity(color1, color2);
        if (similarity > bestMatch) {
          bestMatch = similarity;
        }
      }
      totalSimilarity += bestMatch;
      matches++;
    }
    
    // Weight: 60% dominant color, 40% overall palette
    final averageSimilarity = matches > 0 ? totalSimilarity / matches : 0.0;
    return (dominantSimilarity * 0.6) + (averageSimilarity * 0.4);
  }

  /// Get basic shape/type hint from image dimensions
  /// Returns a simple aspect ratio category
  String getShapeCategory(double width, double height) {
    final aspectRatio = width / height;
    
    if (aspectRatio > 1.5) {
      return 'wide'; // Wide items like bags, books
    } else if (aspectRatio < 0.7) {
      return 'tall'; // Tall items like bottles, phones
    } else {
      return 'square'; // Square-ish items
    }
  }

  /// Convert RGB color to a simple color name (rule-based)
  /// This is the EASIEST AI approach - no ML, just simple rules
  String colorToName(Color color) {
    final r = color.red;
    final g = color.green;
    final b = color.blue;
    
    // Rule-based color classification (simple AI)
    // Black: very dark colors
    if (r < 50 && g < 50 && b < 50) {
      return 'black';
    }
    
    // White: very light colors
    if (r > 200 && g > 200 && b > 200) {
      return 'white';
    }
    
    // Red: high red, low green and blue
    if (r > 200 && g < 100 && b < 100) {
      return 'red';
    }
    
    // Green: green is dominant
    if (g > r && g > b && g > 100) {
      return 'green';
    }
    
    // Blue: blue is dominant
    if (b > r && b > g && b > 100) {
      return 'blue';
    }
    
    // Yellow: high red and green, low blue
    if (r > 150 && g > 150 && b < 100) {
      return 'yellow';
    }
    
    // Orange: high red and green, medium blue
    if (r > 180 && g > 100 && g < 180 && b < 100) {
      return 'orange';
    }
    
    // Purple: high red and blue, low green
    if (r > 100 && b > 100 && g < 100) {
      return 'purple';
    }
    
    // Pink: high red, medium green and blue
    if (r > 180 && g > 100 && g < 180 && b > 100 && b < 180) {
      return 'pink';
    }
    
    // Brown: medium red, low green and blue
    if (r > 100 && r < 180 && g < 100 && b < 100) {
      return 'brown';
    }
    
    // Grey: similar RGB values
    final diff = (r - g).abs() + (g - b).abs() + (b - r).abs();
    if (diff < 50) {
      if (r < 100) {
        return 'dark grey';
      } else if (r > 150) {
        return 'light grey';
      } else {
        return 'grey';
      }
    }
    
    // Default: return the closest match
    if (r > g && r > b) {
      return 'red';
    } else if (g > r && g > b) {
      return 'green';
    } else if (b > r && b > g) {
      return 'blue';
    }
    
    return 'other';
  }

  /// Get dominant color name from an image
  /// Returns a simple color name like "black", "red", "white", etc.
  Future<String> getDominantColorName(XFile imageFile) async {
    try {
      final colors = await extractDominantColors(imageFile);
      if (colors.isEmpty) return 'other';
      
      // Use the first (most dominant) color
      return colorToName(colors[0]);
    } catch (e) {
      print('⚠️ Error getting color name: $e');
      return 'other';
    }
  }

  /// Get close color names (for matching similar colors)
  /// e.g., "black" matches "dark grey", "brown" matches "dark brown"
  List<String> getCloseColorNames(String colorName) {
    final closeColors = <String>[colorName]; // Always include the exact match
    
    switch (colorName.toLowerCase()) {
      case 'black':
        closeColors.addAll(['dark grey', 'grey', 'brown']);
        break;
      case 'dark grey':
        closeColors.addAll(['black', 'grey']);
        break;
      case 'grey':
        closeColors.addAll(['dark grey', 'light grey', 'black']);
        break;
      case 'light grey':
        closeColors.addAll(['grey', 'white']);
        break;
      case 'white':
        closeColors.addAll(['light grey', 'grey']);
        break;
      case 'brown':
        closeColors.addAll(['black', 'dark grey']);
        break;
      case 'red':
        closeColors.addAll(['orange', 'pink']);
        break;
      case 'orange':
        closeColors.addAll(['red', 'yellow']);
        break;
      case 'yellow':
        closeColors.addAll(['orange', 'green']);
        break;
      case 'green':
        closeColors.addAll(['yellow', 'blue']);
        break;
      case 'blue':
        closeColors.addAll(['green', 'purple']);
        break;
      case 'purple':
        closeColors.addAll(['blue', 'pink']);
        break;
      case 'pink':
        closeColors.addAll(['purple', 'red']);
        break;
    }
    
    return closeColors.toSet().toList(); // Remove duplicates
  }
}

