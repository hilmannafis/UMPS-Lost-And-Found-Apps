import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authState;
});

class AuthState {
  const AuthState({required this.profile, this.loading = false, this.error});

  final UserProfile? profile;
  final bool loading;
  final Object? error;

  AuthState copyWith({UserProfile? profile, bool? loading, Object? error}) {
    final newState = AuthState(
      profile: profile ?? this.profile,
      loading: loading ?? this.loading,
      error: error, // Note: error can be explicitly set to null to clear it
    );
    // If error is being set, log it
    if (error != null) {
      print('🔴 AuthState.copyWith - Setting error: $error');
    }
    return newState;
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(ref: ref, repository: repo);
});

class AuthController extends StateNotifier<AuthState> {
  AuthController({required this.ref, required this.repository}) : super(const AuthState(profile: null)) {
    _loadProfile();
  }

  final Ref ref;
  final AuthRepository repository;

  Future<void> _loadProfile() async {
    try {
      final profile = await repository.currentProfile();
      state = state.copyWith(profile: profile);
      
      // Refresh FCM token when profile is loaded (user is logged in)
      if (profile != null) {
        repository.refreshFcmToken().catchError((e) {
          print('⚠️ Failed to refresh FCM token: $e');
        });
      }
    } catch (e) {
      state = state.copyWith(error: e);
    }
  }

  Future<void> loadProfile() async {
    await _loadProfile();
  }

  Future<void> login({
    required String email,
    required String password,
    void Function(Object error)? onError,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await repository.signIn(email: email, password: password);
      await _loadProfile();
      // Clear any previous errors on success
      state = state.copyWith(error: null, loading: false);
    } catch (e) {
      // Store error in state so UI can display it
      print('🔴 AuthController caught error: $e');
      print('🔴 Error type: ${e.runtimeType}');
      state = state.copyWith(error: e, loading: false);
      
      // Call onError callback if provided - UI will handle showing the error
      if (onError != null) {
        onError(e);
      } else {
        // If no callback, rethrow so calling code can catch it
        rethrow;
      }
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String towerNumber,
    required String roomNumber,
    required UserRole role,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await repository.register(
        email: email,
        password: password,
        username: username,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        towerNumber: towerNumber,
        roomNumber: roomNumber,
        role: role,
      );
      await _loadProfile();
      // Clear error on success
      state = state.copyWith(error: null);
    } catch (e) {
      print("🔴 AuthController caught error: $e");
      // Store error in state and rethrow so UI can catch it immediately
      state = state.copyWith(error: e);
      print("🔴 AuthController rethrowing error...");
      rethrow; // ✅ THIS LINE IS CRITICAL - Without this, UI will NEVER see the error
    } finally {
      // Ensure loading is always false
      state = state.copyWith(loading: false);
    }
  }

  Future<void> logout() async {
    await repository.signOut();
    state = const AuthState(profile: null);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await repository.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      state = state.copyWith(error: e);
      rethrow; // Re-throw so UI can show the error
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? towerNumber,
    String? roomNumber,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await repository.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        towerNumber: towerNumber,
        roomNumber: roomNumber,
      );
      await _loadProfile(); // Reload profile to reflect changes
    } catch (e) {
      state = state.copyWith(error: e);
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await repository.sendPasswordReset(email.trim().toLowerCase());
      state = state.copyWith(error: null, loading: false);
    } catch (e) {
      state = state.copyWith(error: e, loading: false);
      rethrow; // Re-throw so UI can show the error
    }
  }
}

