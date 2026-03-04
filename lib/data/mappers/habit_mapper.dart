import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/habit.dart';
import '../database/app_database.dart';

/// Maps between domain Habit entity and Drift HabitRow data class.
class HabitMapper {
  static Habit toDomain(HabitRow db) {
    final scheduledDaysList = (jsonDecode(db.scheduledDays) as List<dynamic>)
        .map((e) => e as int)
        .toList();
    final reminderTimesList =
        (jsonDecode(db.reminderTimes) as List<dynamic>).map((e) {
      final parts = (e as String).split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }).toList();

    return Habit(
      id: db.id,
      title: db.title,
      description: db.description,
      colourValue: db.colourValue,
      iconCodePoint: db.iconCodePoint,
      iconFontFamily: db.iconFontFamily,
      scheduleType: ScheduleType.values[db.scheduleType],
      scheduledDays: scheduledDaysList,
      customFrequencyPerWeek: db.customFrequencyPerWeek,
      goalType: GoalType.values[db.goalType],
      targetQuantity: db.targetQuantity,
      unit: db.unit,
      reminderTimes: reminderTimesList,
      createdAt: db.createdAt,
      updatedAt: db.updatedAt,
      archived: db.archived,
    );
  }

  static HabitsCompanion toCompanion(Habit habit) {
    final scheduledDaysJson = jsonEncode(habit.scheduledDays);
    final reminderTimesJson = jsonEncode(
      habit.reminderTimes
          .map((t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
          .toList(),
    );

    return HabitsCompanion.insert(
      id: habit.id,
      title: habit.title,
      colourValue: habit.colourValue,
      iconCodePoint: habit.iconCodePoint,
      scheduleType: habit.scheduleType.index,
      goalType: habit.goalType.index,
      createdAt: habit.createdAt,
      updatedAt: habit.updatedAt,
    ).copyWith(
      description: habit.description != null
          ? Value(habit.description)
          : const Value(null),
      iconFontFamily: Value(habit.iconFontFamily),
      scheduledDays: Value(scheduledDaysJson),
      customFrequencyPerWeek: Value(habit.customFrequencyPerWeek),
      targetQuantity: habit.targetQuantity != null
          ? Value(habit.targetQuantity)
          : const Value(null),
      unit: habit.unit != null ? Value(habit.unit) : const Value(null),
      reminderTimes: Value(reminderTimesJson),
      archived: Value(habit.archived),
    );
  }
}
