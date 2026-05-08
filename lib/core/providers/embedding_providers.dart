import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/image_embedding_service.dart';

final imageEmbeddingServiceProvider = Provider<ImageEmbeddingService>((ref) {
  return ImageEmbeddingService();
});

