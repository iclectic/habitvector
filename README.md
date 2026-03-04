# Habit Vector

A production-quality Flutter habit tracker focused on daily consistency, streaks, and simple insights. Offline-first, private, and beautifully designed with Firebase authentication.

## Features

- **Authentication**: Sign in with Google, Apple, and Microsoft (scaffolded) via Firebase Auth
- **Habit Tracking**: Create tick (yes/no) or quantity-based habits with flexible scheduling (daily, specific days, or x times per week)
- **Streaks**: Automatic streak calculation for each schedule type with current and longest streak tracking
- **Insights**: Weekly and monthly completion charts, best/struggling habits, completion rates over 7/30/90 days
- **Calendar Heatmap**: Visual 90-day history per habit
- **Reminders**: Local notifications with timezone-safe scheduling and multiple reminder times per habit
- **Data Export/Import**: Full JSON backup and restore with validation
- **Onboarding**: Optional sample habits to get started quickly
- **Theming**: System, light, and dark modes with a consistent design system, persisted via shared_preferences
- **Branding**: Custom vector logo (CustomPainter + SVG), animated splash screen
- **Accessibility**: Semantic labels, scalable text, contrast-aware themes
- **Haptic Feedback**: Tactile response on key actions

## Tech Stack

- **Flutter** (stable channel)
- **State Management**: Riverpod (StateNotifier, StreamProvider, Provider)
- **Authentication**: Firebase Auth (Google, Apple, Microsoft stub)
- **Local Storage**: Drift (SQLite)
- **Charts**: fl_chart
- **Notifications**: flutter_local_notifications with timezone support
- **Splash**: flutter_native_splash (light + dark)
- **SVG**: flutter_svg
- **Architecture**: Clean architecture with layered separation

## Project Structure

```
lib/
  domain/                  # Domain layer (pure Dart, no framework deps)
    entities/              # Habit, HabitLog, StreakInfo
    repositories/          # Abstract interfaces: HabitRepository, HabitLogRepository, AuthRepository
  data/                    # Data layer (framework-dependent)
    database/              # Drift database definition and generated code
    mappers/               # Domain <-> DB mappers
    repositories/          # DriftHabitRepository, DriftHabitLogRepository, FirebaseAuthRepository
    services/              # Notification service
  application/             # Application layer (use cases + controllers)
    auth/                  # AuthController (StateNotifier)
    use_cases/             # StreakCalculator, HabitUseCases, LogUseCases, ExportImport
  presentation/            # Presentation layer (Flutter UI)
    providers/             # Riverpod providers: providers.dart, auth_providers.dart, theme_provider.dart
    theme/                 # AppTheme (colours, typography, spacing)
    widgets/               # Shared widgets: HabitVectorLogo
    screens/
      auth/                # WelcomeScreen, SignInScreen
      splash/              # AnimatedSplashScreen (post-native-splash animation)
      onboarding/          # Onboarding flow
      shell/               # Bottom navigation shell
      home/                # Today dashboard with summary cards and habit tiles
        widgets/           # HabitTile, SummaryCard
      habits/              # Habits list, add/edit, detail
        widgets/           # CalendarHeatmap
      insights/            # Charts and performance rankings
      settings/            # Theme toggle (3-state), account, sign out, notifications, export/import
assets/
  images/                  # Splash PNGs (light + dark)
  svg/                     # habit_vector_logo.svg
test/
  application/             # Unit tests for streak calculation
  data/                    # Repository read/write tests (in-memory DB)
  presentation/            # Widget tests (mark done, add habit)
```

## Setup Instructions

### Prerequisites

1. **Flutter SDK** (stable channel, 3.16+)
   ```
   flutter --version
   ```
2. **Dart SDK** (3.2+, bundled with Flutter)
3. **Firebase CLI** and **FlutterFire CLI** (for auth setup)
   ```
   dart pub global activate flutterfire_cli
   ```

### Step-by-step

1. **Clone or copy the project** into your workspace.

2. **Install dependencies**:
   ```bash
   cd habit_tracker
   flutter pub get
   ```

3. **Configure Firebase**:
   ```bash
   flutterfire configure
   ```
   This generates `lib/firebase_options.dart` and platform config files (`google-services.json`, `GoogleService-Info.plist`).

   Then update `main.dart` to use the generated options:
   ```dart
   import 'firebase_options.dart';
   // In main():
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   ```

4. **Run code generation** (for Drift):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

5. **Generate native splash** (optional, for branded splash screen):
   ```bash
   dart run flutter_native_splash:create
   ```
   Replace placeholder PNGs in `assets/images/` with your actual 1152x1152 brand logos first.

6. **Run on a device or emulator**:
   ```bash
   flutter run
   ```

7. **Run tests**:
   ```bash
   flutter test
   ```

### Platform-specific setup

#### Android
- **Minimum SDK**: 21 (set in `android/app/build.gradle.kts`)
- **Firebase**: Place `google-services.json` in `android/app/` (generated by `flutterfire configure`)
- **Google Sign-In**: Works out of the box with Firebase config
- **Notification channel**: Created automatically

#### iOS
- **Firebase**: Place `GoogleService-Info.plist` in `ios/Runner/` (generated by `flutterfire configure`)
- **Apple Sign-In**: Enable "Sign in with Apple" capability in Xcode:
  1. Open `ios/Runner.xcworkspace` in Xcode
  2. Select Runner target > Signing & Capabilities
  3. Click "+ Capability" > "Sign in with Apple"
  4. Also register the capability in Apple Developer Console > Certificates, Identifiers & Profiles
- **Google Sign-In**: Add the `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` as a URL scheme in Info.plist
- **Background modes**: Already configured for `fetch` and `remote-notification`
- **Notification permissions**: Requested at runtime

## Authentication Architecture

### Flow

```
main() -> AnimatedSplashScreen -> AuthGate -> WelcomeScreen (if unauthenticated)
                                            -> OnboardingGate -> AppShell (if authenticated)
```

### Key Components

- **`AuthRepository`** (interface): Defines `signInWithGoogle()`, `signInWithApple()`, `signInWithMicrosoft()`, `signOut()`, `authStateChanges`
- **`FirebaseAuthRepository`**: Concrete implementation using `firebase_auth`, `google_sign_in`, `sign_in_with_apple`
- **`AuthController`** (StateNotifier): Manages `AuthState` with `status`, `user`, `isLoading`, `errorMessage`
- **`AuthGate`** (widget): Route guard that redirects based on `AuthStatus`
- **Microsoft sign-in**: UI button is present; backend returns a descriptive TODO message. Ready to plug in via `OAuthProvider('microsoft.com')` once Azure AD is configured.

## Theming

- **3-state toggle**: System default, Light, Dark
- **Persisted** via `shared_preferences` using `ThemeNotifier` (StateNotifier)
- **ColourScheme-based**: Uses `colorSchemeSeed` for Material 3 consistency
- **Single source of truth**: `AppTheme` class defines spacing, radii, colours, typography
- **SegmentedButton** in settings for clean theme selection

### Brand Colours

| Role       | Light           | Dark            |
|------------|-----------------|-----------------|
| Primary    | `#4F46E5` (Indigo) | `#818CF8`    |
| Surface    | `#F8FAFC`       | `#0F172A`       |
| Card       | `#FFFFFF`       | `#1E293B`       |
| Error      | `#EF4444`       | `#F87171`       |
| Success    | `#22C55E`       | `#22C55E`       |
| Warning    | `#F59E0B`       | `#F59E0B`       |

## Technical Overview

### Key Decisions

1. **Riverpod over Bloc**: Compile-time safety, simpler boilerplate, natural DI container.
2. **Drift (SQLite)**: Type-safe queries, migration support, in-memory testing.
3. **Clean Architecture**: Four layers (domain, data, application, presentation) for testability.
4. **Firebase Auth**: Industry-standard, handles OAuth complexity, supports multiple providers.
5. **Offline-first**: All habit data is local SQLite. Auth is identity-only; no cloud data sync yet.
6. **Performance**: StreamProviders + Drift reactive queries, IndexedStack tab preservation.

### Design System

- **Logo**: Upward vector arrow with accent dots (CustomPainter + SVG)
- **Colours**: 12 preset habit colours, indigo primary, slate neutrals
- **Typography**: Inter font family (system fallback)
- **Spacing**: 4/8/16/24/32/48 scale
- **Border Radius**: 8/12/16/24 scale
- **Cards**: Outlined style (no elevation) for a clean, modern look

## Recommendations (Now vs Later)

### Now (implemented or ready)

| Feature | Reason | Status |
|---------|--------|--------|
| Onboarding tips | First-run guidance reduces abandonment | Implemented |
| Streaks + reminders | Core motivation loop | Implemented |
| Local notifications | Permission flow included | Implemented |
| Data export (JSON) | Users want data portability | Implemented |
| Theme persistence | Expected UX; avoids re-selecting each launch | Implemented |

### Later (high value, moderate effort)

| Feature | Reason | Outline |
|---------|--------|---------|
| CSV export | Spreadsheet users; add a `toCsv()` method on ExportImportUseCases | 1-2 hours |
| Analytics events | Screen views, sign-in success; use `firebase_analytics` with privacy defaults | 2-3 hours |
| Cloud backup | Encrypted JSON to Firebase Storage or iCloud; add `BackupRepository` interface | 1-2 days |
| Microsoft sign-in | Complete the stubbed `signInWithMicrosoft()`; register in Azure AD + Firebase | 1-2 hours once Azure configured |
| Widget (home screen) | iOS WidgetKit / Android Glance; shows today's completion | 1-2 days |
| Habit templates | Pre-built packs; seed data in onboarding | 3-4 hours |

## Verification Checklist

- [ ] `flutter pub get` succeeds
- [ ] `flutter analyze` reports 0 errors, 0 warnings
- [ ] `flutter test` passes all tests (streak, repository, widget)
- [ ] Android: App displays "Habit Vector" in launcher and app bar
- [ ] iOS: App displays "Habit Vector" in launcher and app bar
- [ ] Firebase initialises without error (after `flutterfire configure`)
- [ ] Google sign-in works on Android and iOS
- [ ] Apple sign-in works on iOS (requires capability)
- [ ] Microsoft button shows descriptive message (not yet configured)
- [ ] Theme toggle (System/Light/Dark) persists across restarts
- [ ] Animated splash screen displays logo then transitions
- [ ] Sign-out returns to Welcome screen
- [ ] Onboarding only shows once after auth
- [ ] Export/import still works after rename

## Possible Pitfalls

1. **Firebase not configured**: App catches the init error and continues, but auth buttons will fail. Run `flutterfire configure` first.
2. **Apple sign-in on Android**: Button is only shown on iOS/macOS. If you need it on Android, use Firebase's `signInWithProvider` instead.
3. **SHA-1 for Google Sign-In (Android)**: Must be registered in Firebase Console. Use `./gradlew signingReport` to get your debug SHA-1.
4. **Apple Developer account**: Sign in with Apple requires an active Apple Developer Program membership and the capability enabled.
5. **Splash logo PNGs**: Placeholders are 1x1 transparent. Replace with 1152x1152 branded PNGs before running `flutter_native_splash:create`.
6. **Database migration**: The SQLite filename is still `habit_flow.sqlite` intentionally to preserve existing user data.

## Licence

This project is provided as-is for educational and personal use.
