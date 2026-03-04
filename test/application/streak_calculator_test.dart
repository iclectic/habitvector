import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/domain/entities/habit.dart';
import 'package:habit_flow/domain/entities/habit_log.dart';
import 'package:habit_flow/application/use_cases/streak_calculator.dart';

void main() {
  const calculator = StreakCalculator();

  DateTime _date(int year, int month, int day) => DateTime(year, month, day);

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Habit _dailyTickHabit() {
    return Habit(
      id: 'habit-1',
      title: 'Daily Exercise',
      colourValue: 0xFF6366F1,
      iconCodePoint: Icons.fitness_center.codePoint,
      scheduleType: ScheduleType.daily,
      goalType: GoalType.tick,
      createdAt: _date(2024, 1, 1),
      updatedAt: _date(2024, 1, 1),
    );
  }

  Habit _specificDaysHabit({List<int> days = const [1, 3, 5]}) {
    return Habit(
      id: 'habit-2',
      title: 'MWF Workout',
      colourValue: 0xFF22C55E,
      iconCodePoint: Icons.fitness_center.codePoint,
      scheduleType: ScheduleType.specificDays,
      scheduledDays: days,
      goalType: GoalType.tick,
      createdAt: _date(2024, 1, 1),
      updatedAt: _date(2024, 1, 1),
    );
  }

  Habit _customFrequencyHabit({int frequency = 3}) {
    return Habit(
      id: 'habit-3',
      title: '3x per week',
      colourValue: 0xFFF59E0B,
      iconCodePoint: Icons.repeat.codePoint,
      scheduleType: ScheduleType.customFrequency,
      customFrequencyPerWeek: frequency,
      goalType: GoalType.tick,
      createdAt: _date(2024, 1, 1),
      updatedAt: _date(2024, 1, 1),
    );
  }

  Habit _quantityHabit() {
    return Habit(
      id: 'habit-4',
      title: 'Drink Water',
      colourValue: 0xFF06B6D4,
      iconCodePoint: Icons.water_drop.codePoint,
      scheduleType: ScheduleType.daily,
      goalType: GoalType.quantity,
      targetQuantity: 8.0,
      unit: 'glasses',
      createdAt: _date(2024, 1, 1),
      updatedAt: _date(2024, 1, 1),
    );
  }

  HabitLog _log(String habitId, DateTime date, {bool completed = true, double? value, bool skipped = false}) {
    return HabitLog(
      id: 'log-${date.toIso8601String()}-$habitId',
      habitId: habitId,
      date: date,
      completed: completed,
      value: value,
      skipped: skipped,
      createdAt: date,
    );
  }

  group('Daily habit streaks', () {
    test('should return 0 streak with no logs', () {
      final habit = _dailyTickHabit();
      final result = calculator.calculate(habit, []);

      expect(result.currentStreak, 0);
      expect(result.longestStreak, 0);
    });

    test('should calculate current streak of consecutive days', () {
      final habit = _dailyTickHabit();
      final today = _today();
      final logs = [
        _log(habit.id, today),
        _log(habit.id, today.subtract(const Duration(days: 1))),
        _log(habit.id, today.subtract(const Duration(days: 2))),
      ];

      final result = calculator.calculate(habit, logs);
      expect(result.currentStreak, 3);
    });

    test('should break streak on missed day', () {
      final habit = _dailyTickHabit();
      final today = _today();
      final logs = [
        _log(habit.id, today),
        // Day -1 missing
        _log(habit.id, today.subtract(const Duration(days: 2))),
        _log(habit.id, today.subtract(const Duration(days: 3))),
      ];

      final result = calculator.calculate(habit, logs);
      expect(result.currentStreak, 1);
    });

    test('should calculate longest streak correctly', () {
      final habit = _dailyTickHabit();
      final today = _today();
      final logs = [
        _log(habit.id, today),
        // Gap
        _log(habit.id, today.subtract(const Duration(days: 5))),
        _log(habit.id, today.subtract(const Duration(days: 6))),
        _log(habit.id, today.subtract(const Duration(days: 7))),
        _log(habit.id, today.subtract(const Duration(days: 8))),
        _log(habit.id, today.subtract(const Duration(days: 9))),
      ];

      final result = calculator.calculate(habit, logs);
      expect(result.longestStreak, 5);
      expect(result.currentStreak, 1);
    });

    test('should count yesterday as current if today not yet done', () {
      final habit = _dailyTickHabit();
      final today = _today();
      final yesterday = today.subtract(const Duration(days: 1));
      final logs = [
        _log(habit.id, yesterday),
        _log(habit.id, yesterday.subtract(const Duration(days: 1))),
      ];

      final result = calculator.calculate(habit, logs);
      expect(result.currentStreak, 2);
    });

    test('should not count skipped days in streak', () {
      final habit = _dailyTickHabit();
      final today = _today();
      final logs = [
        _log(habit.id, today, skipped: true),
        _log(habit.id, today.subtract(const Duration(days: 1))),
        _log(habit.id, today.subtract(const Duration(days: 2))),
      ];

      final result = calculator.calculate(habit, logs);
      // Today is skipped, so streak is based on yesterday backward
      expect(result.currentStreak, 2);
    });
  });

  group('Specific days habit streaks', () {
    test('should return 0 streak with no logs', () {
      final habit = _specificDaysHabit(days: [1, 3, 5]); // Mon, Wed, Fri
      final result = calculator.calculate(habit, []);

      expect(result.currentStreak, 0);
      expect(result.longestStreak, 0);
    });

    test('should count consecutive scheduled days', () {
      final habit = _specificDaysHabit(days: [1, 3, 5]); // Mon, Wed, Fri

      // Find recent Mon, Wed, Fri dates
      final today = _today();
      final recentDates = <DateTime>[];
      for (int i = 0; i < 30; i++) {
        final d = today.subtract(Duration(days: i));
        if ([1, 3, 5].contains(d.weekday)) {
          recentDates.add(d);
        }
        if (recentDates.length >= 4) break;
      }

      // Complete the most recent 3 scheduled days
      final logs = recentDates.take(3).map((d) => _log(habit.id, d)).toList();

      final result = calculator.calculate(habit, logs);
      expect(result.currentStreak, greaterThanOrEqualTo(3));
    });

    test('should calculate longest streak for specific days', () {
      final habit = _specificDaysHabit(days: [1, 3, 5]); // Mon, Wed, Fri
      final today = _today();

      final scheduledDates = <DateTime>[];
      for (int i = 0; i < 60; i++) {
        final d = today.subtract(Duration(days: i));
        if ([1, 3, 5].contains(d.weekday)) {
          scheduledDates.add(d);
        }
      }

      // Complete first 5 recent scheduled days, skip one, then 2 more
      final logs = <HabitLog>[];
      for (int i = 0; i < 5 && i < scheduledDates.length; i++) {
        logs.add(_log(habit.id, scheduledDates[i]));
      }
      // Skip index 5, complete 6 and 7
      if (scheduledDates.length > 7) {
        logs.add(_log(habit.id, scheduledDates[6]));
        logs.add(_log(habit.id, scheduledDates[7]));
      }

      final result = calculator.calculate(habit, logs);
      expect(result.longestStreak, greaterThanOrEqualTo(5));
    });
  });

  group('Custom frequency (weekly) streaks', () {
    test('should return 0 streak with no logs', () {
      final habit = _customFrequencyHabit(frequency: 3);
      final result = calculator.calculate(habit, []);

      expect(result.currentStreak, 0);
      expect(result.longestStreak, 0);
    });

    test('should count streak when weekly goal met', () {
      final habit = _customFrequencyHabit(frequency: 3);
      final today = _today();

      // Find Monday of current week
      final mondayThisWeek =
          today.subtract(Duration(days: today.weekday - 1));

      // Complete 3 times this week and last week
      final logs = [
        _log(habit.id, mondayThisWeek),
        _log(habit.id, mondayThisWeek.add(const Duration(days: 1))),
        _log(habit.id, mondayThisWeek.add(const Duration(days: 2))),
        _log(habit.id, mondayThisWeek.subtract(const Duration(days: 7))),
        _log(habit.id, mondayThisWeek.subtract(const Duration(days: 6))),
        _log(habit.id, mondayThisWeek.subtract(const Duration(days: 5))),
      ];

      final result = calculator.calculate(habit, logs);
      expect(result.currentStreak, greaterThanOrEqualTo(1));
    });

    test('should break weekly streak when goal not met', () {
      final habit = _customFrequencyHabit(frequency: 3);
      final today = _today();
      final mondayThisWeek =
          today.subtract(Duration(days: today.weekday - 1));

      // This week: 3 completions (goal met)
      // Last week: only 1 completion (goal not met)
      // Two weeks ago: 3 completions (goal met)
      final logs = [
        _log(habit.id, mondayThisWeek),
        _log(habit.id, mondayThisWeek.add(const Duration(days: 1))),
        _log(habit.id, mondayThisWeek.add(const Duration(days: 2))),
        _log(habit.id, mondayThisWeek.subtract(const Duration(days: 7))),
        // Only 1 last week - not enough
        _log(habit.id, mondayThisWeek.subtract(const Duration(days: 14))),
        _log(habit.id, mondayThisWeek.subtract(const Duration(days: 13))),
        _log(habit.id, mondayThisWeek.subtract(const Duration(days: 12))),
      ];

      final result = calculator.calculate(habit, logs);
      // Streak should be 1 (this week only, since last week broke it)
      expect(result.currentStreak, lessThanOrEqualTo(2));
      expect(result.longestStreak, greaterThanOrEqualTo(1));
    });
  });

  group('Quantity habit streaks', () {
    test('should count as completed when value meets target', () {
      final habit = _quantityHabit(); // target: 8 glasses
      final today = _today();

      final logs = [
        _log(habit.id, today, value: 8.0, completed: true),
        _log(habit.id, today.subtract(const Duration(days: 1)),
            value: 10.0, completed: true),
        _log(habit.id, today.subtract(const Duration(days: 2)),
            value: 8.0, completed: true),
      ];

      final result = calculator.calculate(habit, logs);
      expect(result.currentStreak, 3);
    });

    test('should not count as completed when value below target', () {
      final habit = _quantityHabit(); // target: 8 glasses
      final today = _today();

      final logs = [
        _log(habit.id, today, value: 8.0, completed: true),
        _log(habit.id, today.subtract(const Duration(days: 1)),
            value: 5.0, completed: false), // Below target
        _log(habit.id, today.subtract(const Duration(days: 2)),
            value: 8.0, completed: true),
      ];

      final result = calculator.calculate(habit, logs);
      expect(result.currentStreak, 1);
      expect(result.longestStreak, 1);
    });
  });

  group('Completion rates', () {
    test('should calculate 7-day rate correctly', () {
      final habit = _dailyTickHabit();
      final today = _today();

      // Complete 5 out of 7 days
      final logs = List.generate(5, (i) {
        return _log(habit.id, today.subtract(Duration(days: i)));
      });

      final result = calculator.calculate(habit, logs);
      expect(result.completionRate7Days, closeTo(5 / 7, 0.01));
    });

    test('should calculate 30-day rate correctly', () {
      final habit = _dailyTickHabit();
      final today = _today();

      // Complete 20 out of 30 days
      final logs = List.generate(20, (i) {
        return _log(habit.id, today.subtract(Duration(days: i)));
      });

      final result = calculator.calculate(habit, logs);
      expect(result.completionRate30Days, closeTo(20 / 30, 0.01));
    });

    test('should return 0 rate with no logs', () {
      final habit = _dailyTickHabit();
      final result = calculator.calculate(habit, []);

      expect(result.completionRate7Days, 0.0);
      expect(result.completionRate30Days, 0.0);
      expect(result.completionRate90Days, 0.0);
    });

    test('should handle specific days rate correctly', () {
      final habit = _specificDaysHabit(days: [1, 3, 5]); // Mon, Wed, Fri
      final today = _today();

      // Find all scheduled days in last 7 days and complete them
      final logs = <HabitLog>[];
      int scheduledCount = 0;
      for (int i = 0; i < 7; i++) {
        final d = today.subtract(Duration(days: i));
        if ([1, 3, 5].contains(d.weekday)) {
          scheduledCount++;
          logs.add(_log(habit.id, d));
        }
      }

      final result = calculator.calculate(habit, logs);
      if (scheduledCount > 0) {
        expect(result.completionRate7Days, closeTo(1.0, 0.01));
      }
    });
  });
}
