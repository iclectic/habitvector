import '../../domain/entities/daily_check_in.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/entities/work_shift.dart';

/// Extracted feature snapshot used by the recommendation engine.
///
/// All fields are nullable — missing context is handled gracefully by the
/// engine rather than treated as an error.
class ContextFeatures {
  /// Today's check-in, if the user completed one.
  final DailyCheckIn? checkIn;

  /// Active shift for today, if any.
  final WorkShift? todayShift;

  /// Completion logs for this habit over the last 90 days.
  final List<HabitLog> recentLogs;

  /// The habit being evaluated.
  final Habit habit;

  /// Today's date (normalised, no time component).
  final DateTime today;

  const ContextFeatures({
    required this.habit,
    required this.today,
    required this.recentLogs,
    this.checkIn,
    this.todayShift,
  });

  // -------------------------------------------------------------------------
  // Derived features
  // -------------------------------------------------------------------------

  /// Available time reported by the user today. Null if not provided.
  int? get availableMinutes => checkIn?.availableMinutes;

  /// Energy level reported today. Null if not provided.
  EnergyLevel? get energyLevel => checkIn?.energyLevel;

  /// Workload level reported today. Null if not provided.
  WorkloadLevel? get workloadLevel => checkIn?.workloadLevel;

  /// Day type reported today. Null if not provided.
  DayType? get dayType => checkIn?.dayType;

  /// Whether today is a rest day per the check-in.
  bool get isRestDay => dayType == DayType.restDay;

  /// Whether today is a shift day per the check-in or a shift exists.
  bool get isShiftDay =>
      dayType == DayType.shiftDay || todayShift != null;

  /// Number of completed logs in the last 7 days.
  int get completionsLast7Days {
    final cutoff = today.subtract(const Duration(days: 7));
    return recentLogs
        .where((l) =>
            l.completed &&
            !l.skipped &&
            !l.normalisedDate.isBefore(cutoff))
        .length;
  }

  /// Number of completed logs in the last 30 days.
  int get completionsLast30Days {
    final cutoff = today.subtract(const Duration(days: 30));
    return recentLogs
        .where((l) =>
            l.completed &&
            !l.skipped &&
            !l.normalisedDate.isBefore(cutoff))
        .length;
  }

  /// How many consecutive days were explicitly missed immediately before today.
  ///
  /// A day with no log entry is treated as unknown, not as a miss.
  /// Only days where a log exists with [completed]=false and [skipped]=false
  /// are counted as misses.
  int get consecutiveMissesBeforeToday {
    int misses = 0;
    for (int i = 1; i <= 14; i++) {
      final d = today.subtract(Duration(days: i));
      if (!habit.isDueOn(d)) continue;
      final log = recentLogs
          .where((l) => l.normalisedDate == d)
          .firstOrNull;
      if (log != null && !log.completed && !log.skipped) {
        misses++;
      } else {
        // No log (unknown) or completed/skipped — stop counting.
        break;
      }
    }
    return misses;
  }

  /// Whether the energy level is low or very low.
  bool get isLowEnergy =>
      energyLevel == EnergyLevel.veryLow || energyLevel == EnergyLevel.low;

  /// Whether the workload is heavy or overwhelming.
  bool get isHighWorkload =>
      workloadLevel == WorkloadLevel.heavy ||
      workloadLevel == WorkloadLevel.overwhelming;

  /// User's self-reported confidence for today. Null if not provided.
  double? get confidenceScore => checkIn?.confidenceScore;

  /// Whether the available time is insufficient for the standard habit
  /// (requires estimated duration to be configured).
  bool get isTimeLimited {
    if (availableMinutes == null) return false;
    return availableMinutes! < 15;
  }

  /// Fields that were used (non-null) for recommendation.
  List<String> get availableFactors {
    final factors = <String>[];
    if (checkIn != null) factors.add('daily_check_in');
    if (energyLevel != null) factors.add('energy_level');
    if (workloadLevel != null) factors.add('workload_level');
    if (dayType != null) factors.add('day_type');
    if (todayShift != null) factors.add('shift_schedule');
    if (availableMinutes != null) factors.add('available_time');
    if (confidenceScore != null) factors.add('confidence_score');
    if (recentLogs.isNotEmpty) factors.add('completion_history');
    return factors;
  }

  /// Fields that were absent but would have improved the recommendation.
  List<String> get missingFactors {
    final missing = <String>[];
    if (checkIn == null) missing.add('daily_check_in');
    if (energyLevel == null && checkIn != null) missing.add('energy_level');
    if (workloadLevel == null && checkIn != null) missing.add('workload_level');
    if (dayType == null && checkIn != null) missing.add('day_type');
    if (todayShift == null) missing.add('shift_schedule');
    if (availableMinutes == null && checkIn != null) {
      missing.add('available_time');
    }
    if (recentLogs.isEmpty) missing.add('completion_history');
    return missing;
  }
}
