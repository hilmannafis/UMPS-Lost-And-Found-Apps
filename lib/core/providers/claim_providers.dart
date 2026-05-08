import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/claim.dart';
import '../repositories/claim_repository.dart';
import '../repositories/message_repository.dart';
import 'auth_controller.dart';
import 'message_providers.dart';

final claimRepositoryProvider = Provider<ClaimRepository>((ref) {
  return ClaimRepository(
    messageRepository: ref.watch(messageRepositoryProvider),
  );
});

final recentClaimsProvider = StreamProvider<List<Claim>>((ref) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<Claim>[]);
      }
      return ref.watch(claimRepositoryProvider).watchRecentClaims(limit: 10);
    },
    loading: () => Stream.value(<Claim>[]),
    error: (_, __) => Stream.value(<Claim>[]),
  );
});

final allClaimsProvider = StreamProvider<List<Claim>>((ref) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<Claim>[]);
      }
      return ref.watch(claimRepositoryProvider).watchAllClaims();
    },
    loading: () => Stream.value(<Claim>[]),
    error: (_, __) => Stream.value(<Claim>[]),
  );
});

final claimsByUserProvider = StreamProvider.family<List<Claim>, String>((ref, userId) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<Claim>[]);
      }
      return ref.watch(claimRepositoryProvider).watchClaimsByUser(userId);
    },
    loading: () => Stream.value(<Claim>[]),
    error: (_, __) => Stream.value(<Claim>[]),
  );
});

final claimsForItemProvider = StreamProvider.family<List<Claim>, String>((ref, itemId) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<Claim>[]);
      }
      return ref.watch(claimRepositoryProvider).watchClaimsForItem(itemId);
    },
    loading: () => Stream.value(<Claim>[]),
    error: (_, __) => Stream.value(<Claim>[]),
  );
});

final claimStreamProvider = StreamProvider.family<Claim?, String>((ref, claimId) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }
      return ref.watch(claimRepositoryProvider).watchClaim(claimId);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

final claimsForOwnerItemsProvider = StreamProvider.family<List<Claim>, String>((ref, ownerId) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<Claim>[]);
      }
      return ref.watch(claimRepositoryProvider).watchClaimsForOwnerItems(ownerId);
    },
    loading: () => Stream.value(<Claim>[]),
    error: (_, __) => Stream.value(<Claim>[]),
  );
});


