import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/image_classifier_service.dart';

final imageClassifierServiceProvider = Provider<ImageClassifierService>((ref) {
  final service = ImageClassifierService();
  ref.onDispose(() => service.dispose());
  return service;
});

