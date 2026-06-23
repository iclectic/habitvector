import 'package:uuid/uuid.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/repositories/habit_log_repository.dart';

/// Use cases for habit log operations.
class LogUseCases {
  final HabitLogRepository _repository;
  final Uuid _uuid;

  LogUseCases(this._repository, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Future<List<HabitLog>> getLogsForHabit(String habitId) =>
      _repository.getLogsForHabit(habitId);

  Future<List<HabitLog>> getLogsForHabitInRange(
          String habitId, DateTime start, DateTime end) =>
      _repository.getLogsForHabitInRange(habitId, start, end);

  Future<List<HabitLog>> getLogsForDate(DateTime date) =>
      _repository.getLogsForDate(date);

  Future<List<HabitLog>> getAllLogsInRange(DateTime start, DateTime end) =>
      _repository.getAllLogsInRange(start, end);

  Stream<List<HabitLog>> watchLogsForDate(DateTime date) =>
      _repository.watchLogsForDate(date);

  Stream<List<HabitLog>> watchLogsForHabit(String habitId) =>
      _repository.watchLogsForHabit(habitId);

  /// Mark a tick habit as done for today.
  Future<HabitLog> markDone(String habitId, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final normalised =
        DateTime(targetDate.year, targetDate.month, targetDate.day);

    final existing =
        await _repository.getLogForHabitOnDate(habitId, normalised);
    if (existing != null) {
      final updated = existing.copyWith(completed: true, skipped: false);
      await _repository.updateLog(updated);
      return updated;
    }

    final log = HabitLog(
      id: _uuid.v4(),
      habitId: habitId,
      date: normalised,
      completed: true,
      createdAt: DateTime.now(),
    );
    await _repository.insertLog(log);
    return log;
  }

  /// Mark a habit as not done (undo completion).
  Future<void> markUndone(String habitId, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final normalised =
        DateTime(targetDate.year, targetDate.month, targetDate.day);

    final existing =
        await _repository.getLogForHabitOnDate(habitId, normalised);
    if (existing != null) {
      await _repository.deleteLog(existing.id);
    }
  }

  /// Log a quantity value for a habit.
  Future<HabitLog> logQuantity(
    String habitId,
    double value,
    Habit habit, {
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final normalised =
        DateTime(targetDate.year, targetDate.month, targetDate.day);

    final completed = habit.targetQuantity != null
        ? value >= habit.targetQuantity!
        : value > 0;

    final existing =
        await _repository.getLogForHabitOnDate(habitId, normalised);
    if (existing != null) {
      final updated = existing.copyWith(
        value: value,
        completed: completed,
        skipped: false,
      );
      await _repository.updateLog(updated);
      return updated;
    }

    final log = HabitLog(
      id: _uuid.v4(),
      habitId: habitId,
      date: normalised,
      completed: completed,
      value: value,
      createdAt: DateTime.now(),
    );
    await _repository.insertLog(log);
    return log;
  }

  /// Skip a habit for a day.
  Future<HabitLog> skip(String habitId, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final normalised =
        DateTime(targetDate.year, targetDate.month, targetDate.day);

    final existing =
        await _repository.getLogForHabitOnDate(habitId, normalised);
    if (existing != null) {
      final updated = existing.copyWith(skipped: true, completed: false);
      await _repository.updateLog(updated);
      return updated;
    }

    final log = HabitLog(
      id: _uuid.v4(),
      habitId: habitId,
      date: normalised,
      completed: false,
      skipped: true,
      createdAt: DateTime.now(),
    );
    await _repository.insertLog(log);
    return log;
  }

  Future<void> deleteLogsForHabit(String habitId) =>
      _repository.deleteLogsForHabit(habitId);
}
