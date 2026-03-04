import '../entities/habit_log.dart';

/// Abstract interface for habit log data operations.
abstract class HabitLogRepository {
  Future<List<HabitLog>> getLogsForHabit(String habitId);
  Future<List<HabitLog>> getLogsForHabitInRange(
    String habitId,
    DateTime start,
    DateTime end,
  );
  Future<List<HabitLog>> getLogsForDate(DateTime date);
  Future<List<HabitLog>> getAllLogsInRange(DateTime start, DateTime end);
  Future<HabitLog?> getLogForHabitOnDate(String habitId, DateTime date);
  Future<void> insertLog(HabitLog log);
  Future<void> updateLog(HabitLog log);
  Future<void> deleteLog(String id);
  Future<void> deleteLogsForHabit(String habitId);
  Stream<List<HabitLog>> watchLogsForDate(DateTime date);
  Stream<List<HabitLog>> watchLogsForHabit(String habitId);
}
