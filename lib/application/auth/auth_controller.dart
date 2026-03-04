import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';

/// State for the authentication controller.
class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controls authentication state and delegates to [AuthRepository].
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<AuthUser?>? _authSub;

  AuthController(this._authRepository) : super(const AuthState()) {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSub = _authRepository.authStateChanges.listen(
      (user) {
        if (user != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: user,
          );
        } else {
          state = const AuthState(
            status: AuthStatus.unauthenticated,
          );
        }
      },
      onError: (_) {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
        );
      },
    );
  }

  /// Clear any displayed error message.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Sign in with Google.
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _authRepository.signInWithGoogle();
    if (!result.success) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Sign in with Apple.
  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _authRepository.signInWithApple();
    if (!result.success) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Sign in with Microsoft.
  Future<void> signInWithMicrosoft() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _authRepository.signInWithMicrosoft();
    if (!result.success) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _authRepository.signOut();
    state = state.copyWith(isLoading: false);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
