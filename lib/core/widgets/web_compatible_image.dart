import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// A widget that displays network images in a web-compatible way
/// Uses Image.network on web and CachedNetworkImage on mobile for better compatibility
class WebCompatibleImage extends StatefulWidget {
  const WebCompatibleImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<WebCompatibleImage> createState() => _WebCompatibleImageState();
}

class _WebCompatibleImageState extends State<WebCompatibleImage> {
  int _retryCount = 0;
  static const int _maxRetries = 2;
  bool _hasError = false;
  String? _currentImageUrl;
  Uint8List? _imageBytes;
  bool _isLoadingBytes = false;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.imageUrl;
    if (kIsWeb) {
      _loadImageAsBytes();
    }
  }

  @override
  void didUpdateWidget(WebCompatibleImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _currentImageUrl = widget.imageUrl;
      _retryCount = 0;
      _hasError = false;
      _imageBytes = null;
      if (kIsWeb) {
        _loadImageAsBytes();
      }
    }
  }

  Future<void> _loadImageAsBytes() async {
    if (_isLoadingBytes) return;
    
    setState(() {
      _isLoadingBytes = true;
      _hasError = false;
    });

    try {
      final uri = Uri.parse(widget.imageUrl);
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _imageBytes = response.bodyBytes;
          _isLoadingBytes = false;
          _hasError = false;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading image bytes: $e');
      setState(() {
        _isLoadingBytes = false;
        _hasError = true;
      });
    }
  }

  void _retryLoad() {
    if (_retryCount < _maxRetries) {
      setState(() {
        _retryCount++;
        _hasError = false;
        _imageBytes = null;
      });
      _loadImageAsBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    // On web, use Image.network directly for better compatibility
    if (kIsWeb) {
      // Validate URL first
      final uri = Uri.tryParse(widget.imageUrl);
      if (uri == null || !uri.hasAbsolutePath) {
        print('⚠️ Invalid image URL on web: ${widget.imageUrl}');
        return widget.errorWidget ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey.shade200,
              child: const Icon(Icons.image_not_supported, color: Colors.grey),
            );
      }

      // Try loading as bytes first (bypasses some CORS issues)
      if (_imageBytes != null) {
        return Image.memory(
          _imageBytes!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          key: ValueKey('${widget.imageUrl}_bytes'),
        );
      }

      // Show loading while fetching bytes
      if (_isLoadingBytes) {
        return widget.placeholder ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey.shade200,
              child: const Center(child: CircularProgressIndicator()),
            );
      }

      // Fallback to Image.network if bytes loading failed
      final imageUrl = _currentImageUrl ?? widget.imageUrl;

      return Image.network(
        imageUrl,
        key: ValueKey('${imageUrl}_$_retryCount'),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return widget.placeholder ??
              Container(
                width: widget.width,
                height: widget.height,
                color: Colors.grey.shade200,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
        },
        errorBuilder: (context, error, stackTrace) {
          if (!_hasError) {
            print('❌ Error loading image on web (attempt ${_retryCount + 1}): ${widget.imageUrl}');
            print('   Error type: ${error.runtimeType}');
            print('   Error: $error');
            
            final errorString = error.toString().toLowerCase();
            if (errorString.contains('statuscode: 0') || 
                errorString.contains('failed') ||
                errorString.contains('network')) {
              print('   ⚠️ CORS or network issue detected.');
              print('   💡 Configuring CORS in Firebase Storage may fix this.');
              print('   💡 Run: gsutil cors set cors.json gs://lostandfound-c39bd.firebasestorage.app');
            }
          }
          
          if (_retryCount < _maxRetries) {
            return GestureDetector(
              onTap: _retryLoad,
              child: Container(
                width: widget.width,
                height: widget.height,
                color: Colors.grey.shade200,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.refresh, color: Colors.grey, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to retry',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }
          
          return widget.errorWidget ??
              Container(
                width: widget.width,
                height: widget.height,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported, color: Colors.grey),
              );
        },
      );
    }

    // On mobile, use CachedNetworkImage for better performance
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      httpHeaders: const {
        'Cache-Control': 'no-cache',
      },
      placeholder: (context, url) => widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey.shade200,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      errorWidget: (context, url, error) {
        print('❌ Error loading image: $url');
        print('   Error: $error');
        return widget.errorWidget ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey.shade200,
              child: const Icon(Icons.image_not_supported, color: Colors.grey),
            );
      },
    );
  }
}

