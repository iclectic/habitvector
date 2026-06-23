import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/drift_habit_repository.dart';
import '../../data/repositories/drift_habit_log_repository.dart';
import '../../data/services/notification_service.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../domain/repositories/habit_log_repository.dart';
import '../../application/use_cases/habit_use_cases.dart';
import '../../application/use_cases/log_use_cases.dart';
import '../../application/use_cases/streak_calculator.dart';
import '../../application/use_cases/export_import_use_cases.dart';

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

// ---------- Selected Date ----------

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});
