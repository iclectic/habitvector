import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';

/// State for the authentication controller.
class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthConfigured;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isAuthConfigured = true,
  });

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool? isLoading,
    String? errorMessage,
    bool? isAuthConfigured,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isAuthConfigured: isAuthConfigured ?? this.isAuthConfigured,
    );
  }
}

/// Controls authentication state and delegates to [AuthRepository].
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<AuthUser?>? _authSub;

  AuthController(this._authRepository)
      : super(AuthState(isAuthConfigured: _authRepository.isConfigured)) {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    if (!_authRepository.isConfigured) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        isAuthConfigured: false,
      );
      return;
    }

    _authSub = _authRepository.authStateChanges.listen(
      (user) {
        if (user != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: user,
            isAuthConfigured: _authRepository.isConfigured,
          );
        } else {
          state = AuthState(
            status: AuthStatus.unauthenticated,
            isAuthConfigured: _authRepository.isConfigured,
          );
        }
      },
      onError: (_) {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          isAuthConfigured: _authRepository.isConfigured,
        );
      },
    );
  }

  /// Clear any displayed error message.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Continue without remote identity. Habit data remains local-only.
  void continueLocally() {
    state = state.copyWith(
      status: AuthStatus.localOnly,
      isLoading: false,
      clearError: true,
      clearUser: true,
    );
  }

  /// Sign in with Google.
  Future<void> signInWithGoogle() async {
    if (!_authRepository.isConfigured) {
      continueLocally();
      return;
    }

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
    if (!_authRepository.isConfigured) {
      continueLocally();
      return;
    }

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
    if (!_authRepository.isConfigured) {
      continueLocally();
      return;
    }

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
    if (_authRepository.isConfigured) {
      await _authRepository.signOut();
    }
    state = AuthState(
      status: AuthStatus.localOnly,
      isAuthConfigured: _authRepository.isConfigured,
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
