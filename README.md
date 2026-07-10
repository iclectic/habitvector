# HabitVector Adaptive Lab

> **A privacy-first, explainable habit experimentation platform for people with irregular schedules.**

[![CI](https://github.com/YOUR_USERNAME/habitvector/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/habitvector/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.22-blue?logo=flutter)
![Tests](https://img.shields.io/badge/tests-259%20passing-brightgreen)
![License](https://img.shields.io/badge/license-personal%20use-lightgrey)

---

## Why HabitVector?

Standard habit trackers are built for people with consistent schedules. They fail shift workers, carers, students, freelancers, and parents — anyone whose context changes day to day. A broken streak on a night-shift day is not failure; it is noise.

HabitVector solves this by treating habit-building as a **personal experiment**:

- It learns which contextual conditions (energy, workload, shift type) make a habit achievable for _you_.
- It suggests the right _version_ of a habit — minimum, standard, or stretch — based on today's context.
- It explains every recommendation in plain language.
- It lets you run structured N-of-1 experiments and read the results without causal overreach.
- It celebrates recovery as much as streaks.
- It never sends your data anywhere without explicit consent.

---

## Architecture

Six-phase clean architecture with four layers:

```
┌─────────────────────────────────────────────────────────┐
│  Presentation  (Flutter widgets, Riverpod providers)     │
├─────────────────────────────────────────────────────────┤
│  Application   (Use cases, engines, analysers)           │
├─────────────────────────────────────────────────────────┤
│  Domain        (Entities, repository interfaces, Clock)  │
├─────────────────────────────────────────────────────────┤
│  Data          (Drift/SQLite, mappers, Firebase Auth)    │
└─────────────────────────────────────────────────────────┘
```

**Key decisions** → see `docs/architecture-decisions/`

| ADR | Decision |
|-----|----------|
| [ADR-001](docs/architecture-decisions/ADR-001-clean-architecture.md) | Clean architecture with four layers |
| [ADR-004](docs/architecture-decisions/ADR-004-additive-migrations.md) | Additive-only SQLite migrations |
| [ADR-005](docs/architecture-decisions/ADR-005-local-recommendation-engine.md) | Local-first on-device ML |
| [ADR-006](docs/architecture-decisions/ADR-006-experiment-privacy-data-retention.md) | Experiment privacy and data retention |
| [ADR-007](docs/architecture-decisions/ADR-007-accessibility-commitment.md) | WCAG 2.1 AA accessibility commitment |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI framework | Flutter 3.22 (stable) |
| State management | Riverpod 2.x (`Provider`, `StreamProvider`, `StateNotifier`) |
| Local storage | Drift 2.x (SQLite, type-safe queries, in-memory testing) |
| Auth (optional) | Firebase Auth — Google + Apple sign-in |
| Charts | fl_chart |
| Notifications | flutter_local_notifications |
| CI | GitHub Actions (analyze + test + APK + iOS build) |

---

## Phase Breakdown

### Phase 0 — Foundations
Core entities, schema v1, clean architecture scaffolding, ADRs, product vision doc.

### Phase 1 — Schema v2 + New Repositories *(99 tests)*
Added `DailyCheckIn`, `WorkShift`, `HabitVersions`, `AdaptiveRecommendation`, `HabitExperiment` entities. Drift schema v2 with additive migration. New repositories with full CRUD + streaming. Riverpod providers wired.

### Phase 2 — Cold-Start Rules + Context *(143 tests)*
`ContextFeatureBuilder` extracts energy, workload, shift type, consecutive misses from raw data. `ColdStartRules` applies 8 deterministic rules to produce an `AdaptiveRecommendation`. `RecommendationEngine` caches recommendations by habit + date. `CheckInUseCases` manages daily context entry.

### Phase 3 — Personalised Scoring + Recovery *(185 tests)*
`RecoveryAnalysisService` tracks miss-run lengths and recovery rates from log history. `PersonalisedScorer` applies Bayesian-style weighted scoring across six context features (energy 25%, workload 20%, recent rate 20%, recovery 15%, time 10%, day type 10%). `RecommendationEngine` routes to cold-start below 14 completions, personalised scorer above.

### Phase 4 — Experiment Engine + Friction Analysis *(243 tests)*
`AssignmentEngine` — alternating (deterministic) and randomised (seeded by `hash(experimentId + index)`) arm assignment. `ExperimentAnalyser` — per-arm completion rates, four evidence levels (insufficient → weak → moderate → strong), non-causal conclusion language. `ExperimentUseCases` — full lifecycle (`draft → active → paused → completed | cancelled`), duplicate date guard, auto-analysis on completion. `FrictionAnalyser` — detects 6 friction categories from log history (day-of-week clusters, weekend drift, Monday friction, high skip rate, energy/workload correlations), sorted by intensity.

### Phase 5 — Privacy + Accessibility *(259 tests)*
`PrivacyConsentService` — analytics opt-in (defaults off), policy version stamping, `clearConsentFlags()` for data deletion. Privacy section in Settings — analytics toggle + Delete All Data (two-step confirmation). Accessibility audit — `Semantics` labels on all interactive widgets (`HabitTile`, toggle, skip, `SummaryCard`), `excludeSemantics` on composite widgets, WCAG 2.1 AA baseline documented in ADR-007.

### Phase 6 — CI + Demo Data + Portfolio *(this phase)*
GitHub Actions CI — analyze, test with coverage, debug APK build, iOS no-sign build. `DemoDataSeeder` — 30-day realistic history, 3 habits, 30 check-ins, 6 night shifts, 1 completed experiment, 1 active experiment. `.gitignore` updated for Firebase secrets, signing keys, coverage. Portfolio README (this document).

---

## Project Structure

```
lib/
  domain/
    entities/          # Habit, HabitLog, DailyCheckIn, WorkShift, HabitVersions,
                       # AdaptiveRecommendation, HabitExperiment, RecoveryMetrics
    repositories/      # Abstract interfaces
    services/          # Clock, PrivacyConsentService
  data/
    database/          # Drift schema v2 + migration
    mappers/           # Domain ↔ DB row mappers
    repositories/      # Drift implementations
    services/          # NotificationService
  application/
    adaptive/          # ContextFeatureBuilder, ColdStartRules, PersonalisedScorer,
                       # RecoveryAnalysisService, RecommendationEngine
    experiments/       # AssignmentEngine, ExperimentAnalyser,
                       # ExperimentUseCases, FrictionAnalyser
    context/           # CheckInUseCases
    use_cases/         # HabitUseCases, LogUseCases, StreakCalculator,
                       # ExportImportUseCases, DemoDataSeeder
    auth/              # AuthController
  presentation/
    providers/         # All Riverpod providers
    theme/             # AppTheme (spacing, colours, typography)
    screens/           # auth, splash, onboarding, shell, home, habits,
                       # insights, settings
    widgets/           # HabitVectorLogo
docs/
  architecture-decisions/   # ADR-001, 004, 005, 006, 007
  plans/                    # Phase plans
  product-vision.md
  system-design.md
  privacy-and-threat-model.md
  innovation-thesis.md
test/
  data/               # Repository + migration tests
  domain/             # Entity unit tests, PrivacyConsentService
  application/        # ColdStartRules, PersonalisedScorer, RecoveryAnalysis,
                       # RecommendationEngine, AssignmentEngine, ExperimentAnalyser,
                       # ExperimentUseCases, FrictionAnalyser
  presentation/       # Widget tests
.github/
  workflows/
    ci.yml            # Analyze + test + build
```

---

## Key Engineering Highlights

### Explainable recommendations
Every `AdaptiveRecommendation` includes `explanation`, `factorsUsed`, `factorsMissing`, and `alternativeAction`. No opaque scores — users can always see why a suggestion was made.

### Non-causal experiment conclusions
`ExperimentAnalyser` conclusions are reviewed against a language policy: "associated with", "observed", "tended to" — never "caused", "proved", or "significantly better". Enforced by tests in `experiment_analyser_test.dart`.

### Testable time
A `Clock` interface (`SystemClock` / `FixedClock`) is injected everywhere time-dependent logic runs, making all temporal behaviour deterministic in tests without mocking.

### Deterministic seeded randomisation
`AssignmentEngine` randomised strategy uses `hash(experimentId + index)` as a seed. The same experiment always produces the same arm sequence — reproducible across sessions and devices, no server needed.

### In-memory Drift for tests
All repository tests use `NativeDatabase.memory()` via `AppDatabase.forTesting()`. Tests are fully isolated, no disk I/O, no teardown race conditions.

---

## Getting Started

### Prerequisites
- Flutter 3.22+ (stable channel): `flutter --version`
- Dart 3.2+
- Firebase CLI (optional): `dart pub global activate flutterfire_cli`

### Setup

```bash
# 1. Install dependencies
flutter pub get

# 2. Generate Drift code
dart run build_runner build --delete-conflicting-outputs

# 3. (Optional) Configure Firebase for Google/Apple sign-in
flutterfire configure

# 4. Run
flutter run

# 5. Test
flutter test

# 6. Analyse
flutter analyze
```

### Demo data

To seed the app with 30 days of realistic data for a shift-worker persona:

```dart
// In a ConsumerWidget
final seeder = ref.read(demoDataSeederProvider);
await seeder.seed();
```

To clear demo data:

```dart
await seeder.clear();
```

---

## Privacy

All habit data, check-ins, recommendations, and experiment results are stored **on-device only** in SQLite. Nothing leaves the device unless you explicitly export or (optionally) enable Firebase Auth.

- **Analytics**: off by default. Opt-in via Settings → Privacy.
- **Delete all data**: Settings → Privacy → Delete All Data (two-step confirmation).
- **Export**: plaintext JSON. The UI warns you before sharing.

Full threat model: [`docs/privacy-and-threat-model.md`](docs/privacy-and-threat-model.md)

---

## CI

GitHub Actions runs on every push to `main` / `develop` and on all PRs:

| Job | What it does |
|-----|-------------|
| `analyze_and_test` | `dart format`, `flutter analyze --fatal-warnings`, `flutter test --coverage` |
| `build_android` | Debug APK — uploads artifact (7-day retention) |
| `build_ios` | `flutter build ios --no-codesign` on `macos-latest` |

---

## Licence

Provided as-is for educational and portfolio use.
