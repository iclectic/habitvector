import '../entities/habit_versions.dart';

/// Abstract interface for habit version definitions.
abstract class HabitVersionsRepository {
  Future<HabitVersions?> getVersionsForHabit(String habitId);
  Future<void> upsertVersions(HabitVersions versions);
  Future<void> deleteVersionsForHabit(String habitId);
  Stream<HabitVersions?> watchVersionsForHabit(String habitId);
}
