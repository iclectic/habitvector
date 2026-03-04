/// Represents the currently authenticated user.
class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String provider;

  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.provider,
  });
}

/// Possible authentication states.
enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
}

/// Result wrapper for auth operations.
class AuthResult {
  final bool success;
  final AuthUser? user;
  final String? errorMessage;

  const AuthResult.success(this.user)
      : success = true,
        errorMessage = null;

  const AuthResult.failure(this.errorMessage)
      : success = false,
        user = null;
}

/// Abstract interface for authentication operations.
/// Implementations can use Firebase, Supabase, or any other backend.
abstract class AuthRepository {
  /// Stream of authentication state changes.
  Stream<AuthUser?> get authStateChanges;

  /// The currently signed-in user, or null.
  AuthUser? get currentUser;

  /// Sign in with Google.
  Future<AuthResult> signInWithGoogle();

  /// Sign in with Apple.
  Future<AuthResult> signInWithApple();

  /// Sign in with Microsoft.
  /// Returns [AuthResult.failure] with a message if not yet implemented.
  Future<AuthResult> signInWithMicrosoft();

  /// Sign out the current user.
  Future<void> signOut();
}
