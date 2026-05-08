import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/item.dart';
import '../repositories/item_repository.dart';
import 'auth_controller.dart';

final itemRepositoryProvider = Provider<ItemRepository>((ref) => ItemRepository());

class ItemsQuery {
  final ItemType? type;
  final String? categoryId;
  final String? userId; // Include userId to force recreation when user changes

  ItemsQuery({this.type, this.categoryId, this.userId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemsQuery &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          categoryId == other.categoryId &&
          userId == other.userId;

  @override
  int get hashCode => type.hashCode ^ categoryId.hashCode ^ (userId?.hashCode ?? 0);
}

final itemsStreamProvider = StreamProvider.family<List<Item>, ItemsQuery>((ref, query) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  // Only create stream if user is authenticated
  return authUser.when(
    data: (user) {
      if (user == null) {
        // Return empty stream if no user
        return Stream.value(<Item>[]);
      }
      return ref.watch(itemRepositoryProvider).watchItems(
            type: query.type,
            categoryId: query.categoryId,
          );
    },
    loading: () => Stream.value(<Item>[]),
    error: (_, __) => Stream.value(<Item>[]),
  );
});

final itemsByOwnerProvider = StreamProvider.family<List<Item>, String>((ref, ownerId) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<Item>[]);
      }
      return ref.watch(itemRepositoryProvider).watchItemsByOwner(ownerId);
    },
    loading: () => Stream.value(<Item>[]),
    error: (_, __) => Stream.value(<Item>[]),
  );
});

final itemStreamProvider = StreamProvider.family<Item?, String>((ref, id) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }
      return ref.watch(itemRepositoryProvider).watchItem(id);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

final claimedItemsByUserProvider = StreamProvider.family<List<Item>, String>((ref, userId) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<Item>[]);
      }
      return ref.watch(itemRepositoryProvider).watchClaimedItemsByUser(userId);
    },
    loading: () => Stream.value(<Item>[]),
    error: (_, __) => Stream.value(<Item>[]),
  );
});

// Provider for admin to view all items (including claimed)
final allItemsForAdminProvider = StreamProvider.family<List<Item>, ItemType?>((ref, type) {
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<Item>[]);
      }
      return ref.watch(itemRepositoryProvider).watchAllItemsForAdmin(type: type);
    },
    loading: () => Stream.value(<Item>[]),
    error: (_, __) => Stream.value(<Item>[]),
  );
});