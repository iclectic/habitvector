import 'package:drift/drift.dart';
import '../../domain/entities/habit_log.dart';
import '../database/app_database.dart';

/// Maps between domain HabitLog entity and Drift HabitLogRow data class.
class HabitLogMapper {
  static HabitLog toDomain(HabitLogRow db) {
    return HabitLog(
      id: db.id,
      habitId: db.habitId,
      date: db.date,
      completed: db.completed,
      value: db.value,
      skipped: db.skipped,
      createdAt: db.createdAt,
    );
  }

  static HabitLogsCompanion toCompanion(HabitLog log) {
    return HabitLogsCompanion.insert(
      id: log.id,
      habitId: log.habitId,
      date: DateTime(log.date.year, log.date.month, log.date.day),
      completed: log.completed,
      createdAt: log.createdAt,
    ).copyWith(
      value: log.value != null ? Value(log.value) : const Value(null),
      skipped: Value(log.skipped),
    );
  }
}
