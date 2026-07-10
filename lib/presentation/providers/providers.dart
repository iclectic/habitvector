import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/drift_habit_repository.dart';
import '../../data/repositories/drift_habit_log_repository.dart';
import '../../data/repositories/drift_context_repository.dart';
import '../../data/repositories/drift_shift_repository.dart';
import '../../data/repositories/drift_habit_versions_repository.dart';
import '../../data/repositories/drift_recommendation_repository.dart';
import '../../data/repositories/drift_experiment_repository.dart';
import '../../data/services/notification_service.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../domain/repositories/habit_log_repository.dart';
import '../../domain/repositories/context_repository.dart';
import '../../domain/repositories/shift_repository.dart';
import '../../domain/repositories/habit_versions_repository.dart';
import '../../domain/repositories/recommendation_repository.dart';
import '../../domain/repositories/experiment_repository.dart';
import '../../application/use_cases/habit_use_cases.dart';
import '../../application/use_cases/log_use_cases.dart';
import '../../application/use_cases/streak_calculator.dart';
import '../../application/use_cases/export_import_use_cases.dart';
import '../../application/context/check_in_use_cases.dart';
import '../../application/adaptive/recommendation_engine.dart';
import '../../application/experiments/experiment_use_cases.dart';
import '../../application/experiments/friction_analyser.dart';
import '../../application/use_cases/demo_data_seeder.dart';
import '../../domain/services/clock.dart';
import '../../domain/services/privacy_consent_service.dart';

// ---------- Privacy ----------

final privacyConsentServiceProvider =
    FutureProvider<PrivacyConsentService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return PrivacyConsentService(prefs);
});

// ---------- Database ----------

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// ---------- Repositories ----------

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return DriftHabitRepository(ref.watch(databaseProvider));
});

final habitLogRepositoryProvider = Provider<HabitLogRepository>((ref) {
  return DriftHabitLogRepository(ref.watch(databaseProvider));
});

final contextRepositoryProvider = Provider<ContextRepository>((ref) {
  return DriftContextRepository(ref.watch(databaseProvider));
});

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return DriftShiftRepository(ref.watch(databaseProvider));
});

final habitVersionsRepositoryProvider =
    Provider<HabitVersionsRepository>((ref) {
  return DriftHabitVersionsRepository(ref.watch(databaseProvider));
});

final recommendationRepositoryProvider =
    Provider<RecommendationRepository>((ref) {
  return DriftRecommendationRepository(ref.watch(databaseProvider));
});

final experimentRepositoryProvider = Provider<ExperimentRepository>((ref) {
  return DriftExperimentRepository(ref.watch(databaseProvider));
});

// ---------- Use Cases ----------

final habitUseCasesProvider = Provider<HabitUseCases>((ref) {
  return HabitUseCases(
    ref.watch(habitRepositoryProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

final logUseCasesProvider = Provider<LogUseCases>((ref) {
  return LogUseCases(ref.watch(habitLogRepositoryProvider));
});

final streakCalculatorProvider = Provider<StreakCalculator>((ref) {
  return const StreakCalculator();
});

final exportImportUseCasesProvider = Provider<ExportImportUseCases>((ref) {
  return ExportImportUseCases(
    ref.watch(habitRepositoryProvider),
    ref.watch(habitLogRepositoryProvider),
  );
});

final checkInUseCasesProvider = Provider<CheckInUseCases>((ref) {
  return CheckInUseCases(
    repo: ref.watch(contextRepositoryProvider),
  );
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final recommendationEngineProvider = Provider<RecommendationEngine>((ref) {
  return RecommendationEngine(
    repo: ref.watch(recommendationRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
});

final experimentUseCasesProvider = Provider<ExperimentUseCases>((ref) {
  return ExperimentUseCases(
    repo: ref.watch(experimentRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
});

final frictionAnalyserProvider = Provider<FrictionAnalyser>((ref) {
  return const FrictionAnalyser();
});

// ---------- Services ----------

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// ---------- Stream Providers ----------

final activeHabitsProvider = StreamProvider((ref) {
  return ref.watch(habitUseCasesProvider).watchActiveHabits();
});

final todayLogsProvider = StreamProvider((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return ref.watch(logUseCasesProvider).watchLogsForDate(today);
});

// ---------- Demo ----------

final demoDataSeederProvider = Provider<DemoDataSeeder>((ref) {
  return DemoDataSeeder(
    habitRepo: ref.watch(habitRepositoryProvider),
    logRepo: ref.watch(habitLogRepositoryProvider),
    contextRepo: ref.watch(contextRepositoryProvider),
    shiftRepo: ref.watch(shiftRepositoryProvider),
    experimentRepo: ref.watch(experimentRepositoryProvider),
  );
});

// ---------- Selected Date ----------

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});
