import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import 'auth_controller.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => NotificationRepository());

final notificationsProvider = StreamProvider.family<List<AppNotification>, String>((ref, userId) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<AppNotification>[]);
      }
      return ref.watch(notificationRepositoryProvider).watchForUser(userId);
    },
    loading: () => Stream.value(<AppNotification>[]),
    error: (_, __) => Stream.value(<AppNotification>[]),
  );
});

final unreadNotificationsProvider = StreamProvider.family<int, String>((ref, userId) {
  // Watch auth state to ensure we have the current user's auth token
  final authUser = ref.watch(authStateProvider);
  
  return authUser.when(
    data: (user) {
      if (user == null) {
        return Stream.value(0);
      }
      return ref.watch(notificationRepositoryProvider).watchForUser(userId).map((notifications) {
        return notifications.where((n) => !n.read).length;
      });
    },
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
  );
});

