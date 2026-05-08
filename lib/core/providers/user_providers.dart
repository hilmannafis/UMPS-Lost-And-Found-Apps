import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'auth_controller.dart';

final usersStreamProvider = StreamProvider<List<UserProfile>>((ref) {
  return ref.watch(authRepositoryProvider).watchUsers(limit: 10);
});

final allUsersStreamProvider = StreamProvider<List<UserProfile>>((ref) {
  return ref.watch(authRepositoryProvider).watchAllUsers();
});

final userProfileProvider = StreamProvider.family<UserProfile?, String>((ref, userId) {
  return ref.watch(authRepositoryProvider).watchUser(userId);
});


