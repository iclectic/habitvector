import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/services/notification_service.dart';
import '../../domain/entities/habit.dart';
import '../../domain/repositories/habit_repository.dart';

/// Use cases for habit CRUD operations.
class HabitUseCases {
  final HabitRepository _repository;
  final NotificationService _notificationService;
  final Uuid _uuid;

  HabitUseCases(
    this._repository, {
    NotificationService? notificationService,
    Uuid? uuid,
  })  : _notificationService = notificationService ?? NotificationService(),
        _uuid = uuid ?? const Uuid();

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
    List<TimeOfDay> reminderTimes = const [],
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Habit title is required.');
    }
    if (trimmedTitle.length > 200) {
      throw ArgumentError.value(title, 'title', 'Habit title is too long.');
    }
    if (scheduleType == ScheduleType.specificDays && scheduledDays.isEmpty) {
      throw ArgumentError.value(
        scheduledDays,
        'scheduledDays',
        'Specific-day habits require at least one scheduled day.',
      );
    }
    if (scheduledDays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError.value(
        scheduledDays,
        'scheduledDays',
        'Scheduled days must use ISO weekday values 1-7.',
      );
    }
    if (customFrequencyPerWeek < 1 || customFrequencyPerWeek > 7) {
      throw ArgumentError.value(
        customFrequencyPerWeek,
        'customFrequencyPerWeek',
        'Custom frequency must be between 1 and 7.',
      );
    }
    if (goalType == GoalType.quantity &&
        (targetQuantity == null || targetQuantity <= 0)) {
      throw ArgumentError.value(
        targetQuantity,
        'targetQuantity',
        'Quantity habits require a positive target.',
      );
    }

    final now = DateTime.now();
    final habit = Habit(
      id: _uuid.v4(),
      title: trimmedTitle,
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
      reminderTimes: reminderTimes,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.insertHabit(habit);
    await _notificationService.scheduleHabitReminders(habit);
    return habit;
  }

  Future<void> updateHabit(Habit habit) async {
    final updated = habit.copyWith(updatedAt: DateTime.now());
    await _repository.updateHabit(updated);
    await _notificationService.scheduleHabitReminders(updated);
  }

  Future<void> archiveHabit(String id) async {
    await _repository.archiveHabit(id);
    await _notificationService.cancelHabitReminders(id);
  }

  Future<void> unarchiveHabit(String id) async {
    await _repository.unarchiveHabit(id);
    final habit = await _repository.getHabitById(id);
    if (habit != null) {
      await _notificationService.scheduleHabitReminders(habit);
    }
  }

  Future<void> deleteHabit(String id) async {
    await _notificationService.cancelHabitReminders(id);
    await _repository.deleteHabit(id);
  }

  /// Get habits that are due on a specific date.
  Future<List<Habit>> getHabitsDueOn(DateTime date) async {
    final habits = await _repository.getActiveHabits();
    return habits.where((h) => h.isDueOn(date)).toList();
  }
}
