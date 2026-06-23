import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/application/auth/auth_controller.dart';
import 'package:habit_flow/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({required this.configured, AuthUser? user})
      : _controller = StreamController<AuthUser?>.broadcast() {
    if (configured) {
      _controller.add(user);
    }
  }

  final bool configured;
  final StreamController<AuthUser?> _controller;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => null;

  @override
  bool get isConfigured => configured;

  @override
  Future<AuthResult> signInWithApple() async {
    return const AuthResult.failure('not implemented');
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    return const AuthResult.failure('not implemented');
  }

  @override
  Future<AuthResult> signInWithMicrosoft() async {
    return const AuthResult.failure('not implemented');
  }

  @override
  Future<void> signOut() async {}

  Future<void> close() => _controller.close();
}

void main() {
  test('starts unauthenticated when remote auth is unconfigured', () async {
    final repository = FakeAuthRepository(configured: false);
    final controller = AuthController(repository);

    expect(controller.state.isAuthConfigured, false);
    expect(controller.state.status, AuthStatus.unauthenticated);

    await repository.close();
    controller.dispose();
  });

  test('continueLocally enters local-only mode without a user', () async {
    final repository = FakeAuthRepository(configured: false);
    final controller = AuthController(repository);

    controller.continueLocally();

    expect(controller.state.status, AuthStatus.localOnly);
    expect(controller.state.user, isNull);
    expect(controller.state.isLoading, false);

    await repository.close();
    controller.dispose();
  });

  test('signOut keeps local habit access available', () async {
    final repository = FakeAuthRepository(configured: true);
    final controller = AuthController(repository);

    await controller.signOut();

    expect(controller.state.status, AuthStatus.localOnly);
    expect(controller.state.isAuthConfigured, true);

    await repository.close();
    controller.dispose();
  });
}
