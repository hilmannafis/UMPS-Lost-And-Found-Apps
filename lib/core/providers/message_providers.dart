import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart';
import '../repositories/message_repository.dart';
import 'auth_controller.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) => MessageRepository());

final messagesStreamProvider = StreamProvider.family<List<Message>, MessageQuery>((ref, query) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<Message>[]);
      }
      return ref.watch(messageRepositoryProvider).watchMessages(
            query.userId1,
            query.userId2,
            query.itemId,
          );
    },
    loading: () => Stream.value(<Message>[]),
    error: (_, __) => Stream.value(<Message>[]),
  );
});

final userChatsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<Map<String, dynamic>>[]);
      }
      return ref.watch(messageRepositoryProvider).watchUserChats(userId);
    },
    loading: () => Stream.value(<Map<String, dynamic>>[]),
    error: (_, __) => Stream.value(<Map<String, dynamic>>[]),
  );
});

class MessageQuery {
  final String userId1;
  final String userId2;
  final String itemId;

  MessageQuery({
    required this.userId1,
    required this.userId2,
    required this.itemId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageQuery &&
          runtimeType == other.runtimeType &&
          userId1 == other.userId1 &&
          userId2 == other.userId2 &&
          itemId == other.itemId;

  @override
  int get hashCode => userId1.hashCode ^ userId2.hashCode ^ itemId.hashCode;
}

