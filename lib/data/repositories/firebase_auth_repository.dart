import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../domain/repositories/auth_repository.dart';

/// Firebase-backed implementation of [AuthRepository].
class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  FirebaseAuthRepository({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  AuthUser? _mapFirebaseUser(fb.User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      provider: user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'firebase',
    );
  }

  @override
  Stream<AuthUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(_mapFirebaseUser);
  }

  @override
  AuthUser? get currentUser => _mapFirebaseUser(_firebaseAuth.currentUser);

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const AuthResult.failure('Google sign-in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final user = _mapFirebaseUser(userCredential.user);
      if (user != null) {
        return AuthResult.success(user);
      }
      return const AuthResult.failure('Failed to retrieve user after sign-in.');
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.failure(e.message ?? 'Google sign-in failed.');
    } catch (e) {
      return AuthResult.failure('Google sign-in failed: $e');
    }
  }

  @override
  Future<AuthResult> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = fb.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(oauthCredential);

      // Apple may only send display name on first sign-in.
      final displayName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].where((n) => n != null && n.isNotEmpty).join(' ');

      if (displayName.isNotEmpty &&
          (userCredential.user?.displayName == null ||
              userCredential.user!.displayName!.isEmpty)) {
        await userCredential.user?.updateDisplayName(displayName);
      }

      final user = _mapFirebaseUser(userCredential.user);
      if (user != null) {
        return AuthResult.success(user);
      }
      return const AuthResult.failure('Failed to retrieve user after sign-in.');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const AuthResult.failure('Apple sign-in was cancelled.');
      }
      return AuthResult.failure('Apple sign-in failed: ${e.message}');
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.failure(e.message ?? 'Apple sign-in failed.');
    } catch (e) {
      return AuthResult.failure('Apple sign-in failed: $e');
    }
  }

  @override
  Future<AuthResult> signInWithMicrosoft() async {
    // TODO: Implement Microsoft sign-in via OAuthProvider('microsoft.com').
    // Steps to implement:
    // 1. Register the app in Azure AD / Microsoft Identity Platform.
    // 2. Add the redirect URI to Firebase console under Microsoft provider.
    // 3. Use fb.OAuthProvider('microsoft.com') with signInWithProvider.
    //
    // Example implementation:
    // final provider = fb.OAuthProvider('microsoft.com');
    // provider.addScope('email');
    // provider.addScope('profile');
    // final userCredential = await _firebaseAuth.signInWithProvider(provider);
    // return AuthResult.success(_mapFirebaseUser(userCredential.user)!);
    return const AuthResult.failure(
      'Microsoft sign-in is not yet configured. '
      'Please set up Azure AD credentials in Firebase console first.',
    );
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Generates a cryptographically secure random nonce.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Returns the SHA-256 hash of [input] as a hex string.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
