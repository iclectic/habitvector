import '../entities/habit.dart';

/// Abstract interface for habit data operations.
abstract class HabitRepository {
  Future<List<Habit>> getAllHabits();
  Future<List<Habit>> getActiveHabits();
  Future<List<Habit>> getArchivedHabits();
  Future<Habit?> getHabitById(String id);
  Future<void> insertHabit(Habit habit);
  Future<void> updateHabit(Habit habit);
  Future<void> deleteHabit(String id);
  Future<void> archiveHabit(String id);
  Future<void> unarchiveHabit(String id);
  Stream<List<Habit>> watchActiveHabits();
  Stream<Habit?> watchHabitById(String id);
}
