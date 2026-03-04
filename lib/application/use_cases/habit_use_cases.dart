import 'package:uuid/uuid.dart';
import '../../domain/entities/habit.dart';
import '../../domain/repositories/habit_repository.dart';

/// Use cases for habit CRUD operations.
class HabitUseCases {
  final HabitRepository _repository;
  final Uuid _uuid;

  HabitUseCases(this._repository, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Future<List<Habit>> getActiveHabits() => _repository.getActiveHabits();

  Future<List<Habit>> getArchivedHabits() => _repository.getArchivedHabits();

  Future<Habit?> getHabitById(String id) => _repository.getHabitById(id);

  Stream<List<Habit>> watchActiveHabits() => _repository.watchActiveHabits();

  Stream<Habit?> watchHabitById(String id) => _repository.watchHabitById(id);

  Future<Habit> createHabit({
    required String title,
    String? description,
    required int colourValue,
    required int iconCodePoint,
    String iconFontFamily = 'MaterialIcons',
    required ScheduleType scheduleType,
    List<int> scheduledDays = const [],
    int customFrequencyPerWeek = 1,
    required GoalType goalType,
    double? targetQuantity,
    String? unit,
    List<dynamic> reminderTimes = const [],
  }) async {
    final now = DateTime.now();
    final habit = Habit(
      id: _uuid.v4(),
      title: title,
      description: description,
      colourValue: colourValue,
      iconCodePoint: iconCodePoint,
      iconFontFamily: iconFontFamily,
      scheduleType: scheduleType,
      scheduledDays: scheduledDays,
      customFrequencyPerWeek: customFrequencyPerWeek,
      goalType: goalType,
      targetQuantity: targetQuantity,
      unit: unit,
      reminderTimes: reminderTimes.cast(),
      createdAt: now,
      updatedAt: now,
    );
    await _repository.insertHabit(habit);
    return habit;
  }

  Future<void> updateHabit(Habit habit) async {
    final updated = habit.copyWith(updatedAt: DateTime.now());
    await _repository.updateHabit(updated);
  }

  Future<void> archiveHabit(String id) => _repository.archiveHabit(id);

  Future<void> unarchiveHabit(String id) => _repository.unarchiveHabit(id);

  Future<void> deleteHabit(String id) => _repository.deleteHabit(id);

  /// Get habits that are due on a specific date.
  Future<List<Habit>> getHabitsDueOn(DateTime date) async {
    final habits = await _repository.getActiveHabits();
    return habits.where((h) => h.isDueOn(date)).toList();
  }
}
