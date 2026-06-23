import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/auth/auth_controller.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/habit_vector_logo.dart';

/// Sign-in screen with Google, Apple, and Microsoft options.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final isDark = theme.brightness == Brightness.dark;

    // Listen for errors and show snackbar
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {
                ref.read(authControllerProvider.notifier).clearError();
              },
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 1),
              HabitVectorLogo(
                size: 80,
                primaryColor:
                    isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
              ),
              const SizedBox(height: 24),
              Text(
                'Sign in to Habit Vector',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                authState.isAuthConfigured
                    ? 'Choose your preferred sign-in method'
                    : 'Firebase is not configured. You can continue locally.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 1),

              // Loading overlay
              if (authState.isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: CircularProgressIndicator(),
                ),

              // Google sign-in button
              _SignInButton(
                onPressed: authState.isLoading || !authState.isAuthConfigured
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle();
                      },
                icon: _googleIcon(isDark),
                label: 'Continue with Google',
                backgroundColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                foregroundColor:
                    isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1F2937),
                borderColor:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              const SizedBox(height: 12),

              // Apple sign-in button (iOS and macOS)
              if (Platform.isIOS || Platform.isMacOS) ...[
                _SignInButton(
                  onPressed: authState.isLoading || !authState.isAuthConfigured
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(authControllerProvider.notifier)
                              .signInWithApple();
                        },
                  icon: Icon(
                    Icons.apple_rounded,
                    size: 22,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  label: 'Continue with Apple',
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                ),
                const SizedBox(height: 12),
              ],

              _SignInButton(
                onPressed: null,
                icon: _microsoftIcon(),
                label: 'Microsoft sign-in coming later',
                backgroundColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                foregroundColor:
                    isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1F2937),
                borderColor:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: authState.isLoading
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(authControllerProvider.notifier)
                              .continueLocally();
                        },
                  child: const Text('Continue Without Sign-In'),
                ),
              ),

              const Spacer(flex: 2),

              Text.rich(
                TextSpan(
                  text: 'By signing in, you agree to our ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  children: [
                    TextSpan(
                      text: 'Terms',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      // TODO: Add GestureRecognizer to open terms URL
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      // TODO: Add GestureRecognizer to open privacy URL
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _googleIcon(bool isDark) {
    // Simple Google "G" using Material icon as fallback
    return SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }

  Widget _microsoftIcon() {
    // Simple 2x2 grid representing the Microsoft logo
    return SizedBox(
      width: 20,
      height: 20,
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          ColoredBox(color: Color(0xFFF25022)), // Red
          ColoredBox(color: Color(0xFF7FBA00)), // Green
          ColoredBox(color: Color(0xFF00A4EF)), // Blue
          ColoredBox(color: Color(0xFFFFB900)), // Yellow
        ],
      ),
    );
  }
}

/// Reusable social sign-in button.
class _SignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  const _SignInButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: BorderSide(
            color: borderColor ?? backgroundColor,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
