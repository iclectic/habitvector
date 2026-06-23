import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/services/notification_service.dart';
import 'domain/repositories/auth_repository.dart';
import 'presentation/providers/auth_providers.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/screens/auth/welcome_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/shell/app_shell.dart';
import 'presentation/screens/splash/animated_splash_screen.dart';

final authConfiguredProvider = Provider<bool>((ref) => true);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final authConfigured = await _initialiseFirebase();

  await NotificationService().initialise();

  runApp(
    ProviderScope(
      overrides: [
        authConfiguredProvider.overrideWithValue(authConfigured),
      ],
      child: const HabitVectorApp(),
    ),
  );
}

Future<bool> _initialiseFirebase() async {
  try {
    await Firebase.initializeApp();
    return true;
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
    return false;
  }
}

class HabitVectorApp extends ConsumerWidget {
  const HabitVectorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp(
      title: 'Habit Vector',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode.toThemeMode(),
      home: const AnimatedSplashScreen(
        nextScreen: _AuthGate(),
      ),
    );
  }
}

/// Route guard that checks authentication state.
/// Unauthenticated users see the [WelcomeScreen].
/// Authenticated users proceed to onboarding check or the main app.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    switch (authState.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.unauthenticated:
        return const WelcomeScreen();
      case AuthStatus.localOnly:
        return const _OnboardingGate();
      case AuthStatus.authenticated:
        return const _OnboardingGate();
    }
  }
}

/// Checks whether onboarding has been completed.
class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate();

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final complete = prefs.getBool('onboarding_complete') ?? false;
    if (mounted) {
      setState(() => _onboardingComplete = complete);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingComplete == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_onboardingComplete!) {
      return const AppShell();
    }

    return OnboardingScreen(
      onComplete: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_complete', true);
        if (mounted) {
          setState(() => _onboardingComplete = true);
        }
      },
    );
  }
}
