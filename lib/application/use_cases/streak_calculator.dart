import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/entities/streak_info.dart';

/// Calculates streaks and completion rates for habits.
///
/// Streak rules:
/// - Daily: consecutive calendar days completed
/// - Specific days: consecutive scheduled days completed
/// - Custom frequency (x per week): consecutive weeks with goal met
class StreakCalculator {
  const StreakCalculator();

  /// Compute full streak info for a habit given its logs.
  StreakInfo calculate(Habit habit, List<HabitLog> logs) {
    final completedLogs = _completedLogs(habit, logs);
    final currentStreak = _currentStreak(habit, completedLogs);
    final longestStreak = _longestStreak(habit, completedLogs);
    final now = DateTime.now();
    final rate7 = _completionRate(habit, logs, now, 7);
    final rate30 = _completionRate(habit, logs, now, 30);
    final rate90 = _completionRate(habit, logs, now, 90);

    return StreakInfo(
      habitId: habit.id,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      completionRate7Days: rate7,
      completionRate30Days: rate30,
      completionRate90Days: rate90,
    );
  }

  /// Filter logs to only those that count as completed.
  List<HabitLog> _completedLogs(Habit habit, List<HabitLog> logs) {
    return logs.where((log) {
      if (log.skipped) return false;
      if (habit.goalType == GoalType.tick) return log.completed;
      // Quantity: completed if value meets or exceeds target
      if (habit.targetQuantity != null && log.value != null) {
        return log.value! >= habit.targetQuantity!;
      }
      return log.completed;
    }).toList();
  }

  /// Compute current streak.
  int _currentStreak(Habit habit, List<HabitLog> completedLogs) {
    switch (habit.scheduleType) {
      case ScheduleType.daily:
        return _currentDailyStreak(completedLogs);
      case ScheduleType.specificDays:
        return _currentSpecificDaysStreak(habit, completedLogs);
      case ScheduleType.customFrequency:
        return _currentWeeklyStreak(habit, completedLogs);
    }
  }

  /// Compute longest streak.
  int _longestStreak(Habit habit, List<HabitLog> completedLogs) {
    switch (habit.scheduleType) {
      case ScheduleType.daily:
        return _longestDailyStreak(completedLogs);
      case ScheduleType.specificDays:
        return _longestSpecificDaysStreak(habit, completedLogs);
      case ScheduleType.customFrequency:
        return _longestWeeklyStreak(habit, completedLogs);
    }
  }

  // ---------- Daily streaks ----------

  int _currentDailyStreak(List<HabitLog> completedLogs) {
    final dates = _sortedUniqueDates(completedLogs);
    if (dates.isEmpty) return 0;

    final today = _today();
    final yesterday = today.subtract(const Duration(days: 1));

    // Current streak must include today or yesterday
    if (dates.last != today && dates.last != yesterday) return 0;

    int streak = 1;
    for (int i = dates.length - 2; i >= 0; i--) {
      final diff = dates[i + 1].difference(dates[i]).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _longestDailyStreak(List<HabitLog> completedLogs) {
    final dates = _sortedUniqueDates(completedLogs);
    if (dates.isEmpty) return 0;

    int longest = 1;
    int current = 1;
    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  // ---------- Specific days streaks ----------

  int _currentSpecificDaysStreak(Habit habit, List<HabitLog> completedLogs) {
    final scheduledDates = _scheduledDatesBackward(habit, 365);
    if (scheduledDates.isEmpty) return 0;

    final completedSet = completedLogs.map((l) => _normalise(l.date)).toSet();

    int streak = 0;
    for (final date in scheduledDates) {
      if (completedSet.contains(date)) {
        streak++;
      } else {
        // Allow today to not yet be completed
        if (date == _today()) continue;
        break;
      }
    }
    return streak;
  }

  int _longestSpecificDaysStreak(Habit habit, List<HabitLog> completedLogs) {
    final scheduledDates = _scheduledDatesForward(habit, completedLogs);
    if (scheduledDates.isEmpty) return 0;

    final completedSet = completedLogs.map((l) => _normalise(l.date)).toSet();

    int longest = 0;
    int current = 0;
    for (final date in scheduledDates) {
      if (completedSet.contains(date)) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    return longest;
  }

  // ---------- Custom frequency (weekly) streaks ----------

  int _currentWeeklyStreak(Habit habit, List<HabitLog> completedLogs) {
    final weekCounts = _weeklyCompletionCounts(completedLogs);
    if (weekCounts.isEmpty) return 0;

    final target = habit.customFrequencyPerWeek;
    final sortedWeeks = weekCounts.keys.toList()..sort();

    final currentWeekStart = _weekStart(_today());
    final lastWeekStart = currentWeekStart.subtract(const Duration(days: 7));

    // Must include current or last week
    if (sortedWeeks.last != currentWeekStart &&
        sortedWeeks.last != lastWeekStart) {
      return 0;
    }

    int streak = 0;
    for (int i = sortedWeeks.length - 1; i >= 0; i--) {
      final weekStart = sortedWeeks[i];
      final count = weekCounts[weekStart] ?? 0;
      if (count >= target) {
        streak++;
      } else {
        // Allow current week to be in progress
        if (weekStart == currentWeekStart) continue;
        break;
      }
    }
    return streak;
  }

  int _longestWeeklyStreak(Habit habit, List<HabitLog> completedLogs) {
    final weekCounts = _weeklyCompletionCounts(completedLogs);
    if (weekCounts.isEmpty) return 0;

    final target = habit.customFrequencyPerWeek;
    final sortedWeeks = weekCounts.keys.toList()..sort();

    int longest = 0;
    int current = 0;
    DateTime? prevWeek;

    for (final weekStart in sortedWeeks) {
      final count = weekCounts[weekStart] ?? 0;
      if (count >= target) {
        if (prevWeek != null && weekStart.difference(prevWeek).inDays == 7) {
          current++;
        } else {
          current = 1;
        }
        if (current > longest) longest = current;
        prevWeek = weekStart;
      } else {
        current = 0;
        prevWeek = null;
      }
    }
    return longest;
  }

  // ---------- Completion rate ----------

  double _completionRate(
    Habit habit,
    List<HabitLog> allLogs,
    DateTime now,
    int days,
  ) {
    final start = _normalise(now.subtract(Duration(days: days - 1)));
    final end = _normalise(now);

    int scheduledCount = 0;
    int completedCount = 0;

    final completedLogs = _completedLogs(habit, allLogs);
    final completedSet = completedLogs.map((l) => _normalise(l.date)).toSet();

    for (int i = 0; i < days; i++) {
      final date = start.add(Duration(days: i));
      if (date.isAfter(end)) break;

      if (habit.isDueOn(date)) {
        scheduledCount++;
        if (completedSet.contains(date)) {
          completedCount++;
        }
      }
    }

    if (scheduledCount == 0) return 0.0;
    return completedCount / scheduledCount;
  }

  // ---------- Helpers ----------

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _normalise(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _weekStart(DateTime d) {
    final normalised = _normalise(d);
    final daysFromMonday = normalised.weekday - 1;
    return normalised.subtract(Duration(days: daysFromMonday));
  }

  List<DateTime> _sortedUniqueDates(List<HabitLog> logs) {
    final dates = logs.map((l) => _normalise(l.date)).toSet().toList()..sort();
    return dates;
  }

  /// Generate scheduled dates going backward from today.
  List<DateTime> _scheduledDatesBackward(Habit habit, int maxDays) {
    final today = _today();
    final dates = <DateTime>[];
    for (int i = 0; i < maxDays; i++) {
      final date = today.subtract(Duration(days: i));
      if (habit.scheduledDays.contains(date.weekday)) {
        dates.add(date);
      }
    }
    return dates; // Most recent first
  }

  /// Generate scheduled dates in chronological order from first log to today.
  List<DateTime> _scheduledDatesForward(
      Habit habit, List<HabitLog> completedLogs) {
    if (completedLogs.isEmpty) return [];
    final sortedDates = _sortedUniqueDates(completedLogs);
    final start = sortedDates.first;
    final end = _today();
    final dates = <DateTime>[];
    var current = start;
    while (!current.isAfter(end)) {
      if (habit.scheduledDays.contains(current.weekday)) {
        dates.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  /// Count completions per ISO week start (Monday).
  Map<DateTime, int> _weeklyCompletionCounts(List<HabitLog> completedLogs) {
    final counts = <DateTime, int>{};
    for (final log in completedLogs) {
      final ws = _weekStart(log.date);
      counts[ws] = (counts[ws] ?? 0) + 1;
    }
    return counts;
  }
}
