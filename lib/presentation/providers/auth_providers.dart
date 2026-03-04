import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth/auth_controller.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';

/// Provides the [AuthRepository] implementation.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

/// Provides the [AuthController] which manages authentication state.
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

/// Convenience provider that exposes the current [AuthStatus].
final authStatusProvider = Provider<AuthStatus>((ref) {
  return ref.watch(authControllerProvider).status;
});

/// Convenience provider that exposes the current [AuthUser].
final authUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authControllerProvider).user;
});
