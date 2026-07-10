# HabitVector Adaptive Lab — System Design

## Architecture Overview

HabitVector uses Clean Architecture with four layers. Domain logic has no dependency on Flutter widgets or external services.

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  Riverpod providers → Screens → Widgets                     │
└────────────────────────┬────────────────────────────────────┘
                         │ (depends on)
┌────────────────────────▼────────────────────────────────────┐
│                   Application Layer                          │
│  Use Cases · Controllers · Services · Recommendation Engine  │
└────────────────────────┬────────────────────────────────────┘
                         │ (depends on)
┌────────────────────────▼────────────────────────────────────┐
│                     Domain Layer                             │
│  Entities · Repository Interfaces · Domain Services          │
└────────────────────────┬────────────────────────────────────┘
                         │ (implemented by)
┌────────────────────────▼────────────────────────────────────┐
│                      Data Layer                              │
│  Drift (SQLite) · Mappers · Firebase Auth · Notifications    │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure (Target)

```
lib/
  domain/
    entities/
      habit.dart                     (existing)
      habit_log.dart                 (existing)
      streak_info.dart               (existing)
      habit_context.dart             (Phase 1)
      daily_check_in.dart            (Phase 1)
      work_shift.dart                (Phase 1)
      habit_versions.dart            (Phase 1)
      adaptive_recommendation.dart   (Phase 1)
      habit_experiment.dart          (Phase 1)
      experiment_observation.dart    (Phase 1)
      recovery_metrics.dart          (Phase 1)
    repositories/
      habit_repository.dart          (existing)
      habit_log_repository.dart      (existing)
      auth_repository.dart           (existing)
      context_repository.dart        (Phase 1)
      shift_repository.dart          (Phase 1)
      recommendation_repository.dart (Phase 1)
      experiment_repository.dart     (Phase 1)
      analytics_repository.dart      (Phase 5)
    services/
      clock.dart                     (Phase 1 — testable time abstraction)
  application/
    auth/
      auth_controller.dart           (existing)
    use_cases/
      habit_use_cases.dart           (existing)
      log_use_cases.dart             (existing)
      streak_calculator.dart         (existing)
      export_import_use_cases.dart   (existing, extended Phase 5)
    adaptive/
      recommendation_engine.dart     (Phase 2)
      cold_start_rules.dart          (Phase 2)
      context_feature_builder.dart   (Phase 2)
    experiments/
      experiment_analysis_service.dart (Phase 4)
      experiment_assignment_engine.dart (Phase 4)
    recovery/
      recovery_analysis_service.dart (Phase 4)
    context/
      check_in_use_cases.dart        (Phase 2)
      shift_use_cases.dart           (Phase 2)
  data/
    database/
      app_database.dart              (existing, extended each phase)
    mappers/
      habit_mapper.dart              (existing)
      habit_log_mapper.dart          (existing)
      check_in_mapper.dart           (Phase 1)
      shift_mapper.dart              (Phase 1)
      recommendation_mapper.dart     (Phase 1)
      experiment_mapper.dart         (Phase 1)
    repositories/
      drift_habit_repository.dart    (existing)
      drift_habit_log_repository.dart (existing)
      firebase_auth_repository.dart  (existing)
      drift_context_repository.dart  (Phase 1)
      drift_shift_repository.dart    (Phase 1)
      drift_recommendation_repository.dart (Phase 1)
      drift_experiment_repository.dart (Phase 1)
    services/
      notification_service.dart      (existing)
  presentation/
    providers/
      providers.dart                 (existing, extended)
      auth_providers.dart            (existing)
      theme_provider.dart            (existing)
      adaptive_providers.dart        (Phase 2)
      experiment_providers.dart      (Phase 4)
    screens/
      auth/                          (existing)
      habits/                        (existing)
      home/                          (existing)
      insights/                      (existing, extended Phase 4)
      onboarding/                    (existing)
      settings/                      (existing)
      shell/                         (existing, extended)
      splash/                        (existing)
      adaptive_plan/                 (Phase 2)
      experiments/                   (Phase 4)
      recovery/                      (Phase 4)
      privacy/                       (Phase 5)
    theme/
      app_theme.dart                 (existing)
    widgets/                         (existing, extended)
```

## Database Schema (v2 — Phase 1 additions)

### Existing (v1, unchanged)
- `habits` — Habit records
- `habit_logs` — Daily completion logs

### New in v2 (additive only)
- `daily_check_ins` — Optional daily context snapshots
- `work_shifts` — Shift schedule entries
- `habit_versions` — Min/standard/stretch version definitions per habit
- `adaptive_recommendations` — Recommendation results with feedback
- `habit_experiments` — Experiment definitions
- `experiment_observations` — Per-assignment data points
- `model_metadata` — Stored model version and parameter snapshots
- `analytics_events` — Local-only event log (consent-gated)

## Data Flow

```
User Action
    │
    ▼
Presentation (Screen / Widget)
    │ reads from provider
    ▼
Riverpod Provider
    │ watches/calls
    ▼
Application Use Case / Controller
    │ calls
    ▼
Domain Repository Interface
    │ implemented by
    ▼
Data Repository (Drift)
    │ reads/writes
    ▼
SQLite (habit_flow.sqlite) — local, on-device
```

## Privacy Boundaries

```
┌─────────────────────────────────────────────┐
│         Device (on-device only)              │
│  ┌──────────────────────────────────────┐   │
│  │  SQLite (habit_flow.sqlite)          │   │
│  │  All habit, log, context, shift,     │   │
│  │  recommendation, experiment data     │   │
│  └──────────────────────────────────────┘   │
│  SharedPreferences (theme, onboarding flags) │
└──────────────┬──────────────────────────────┘
               │ ONLY with explicit consent
               ▼
┌─────────────────────────────────────────────┐
│   External (opt-in, explicit consent only)  │
│  Firebase Auth (identity only, no habit     │
│  data sent)                                  │
│  Optional analytics (anonymous, aggregated) │
│  Optional AI coach (redacted, consent-gated)│
└─────────────────────────────────────────────┘
```

## Key Architectural Decisions

See `docs/architecture-decisions/` for full ADRs.

- **ADR-001**: Clean Architecture layer separation
- **ADR-002**: Drift (SQLite) for local-first storage
- **ADR-003**: Riverpod for state management
- **ADR-004**: Additive-only database migrations
- **ADR-005**: Local recommendation engine with interface for future replacement
- **ADR-006**: Explainability-first recommendation results
- **ADR-007**: N-of-1 experiment design with responsible uncertainty language
- **ADR-008**: Clock abstraction for testable time-dependent logic
