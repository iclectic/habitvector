import '../../domain/entities/daily_check_in.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';

/// A single friction signal identified in the log history.
class FrictionSignal {
  /// Human-readable label for the pattern (e.g. "Monday skip cluster").
  final String label;

  /// Longer explanation of the pattern and what it might mean.
  final String description;

  /// 0.0–1.0 intensity: how pronounced the pattern is relative to the
  /// overall completion rate. Higher = more actionable.
  final double intensity;

  /// Category of friction.
  final FrictionCategory category;

  const FrictionSignal({
    required this.label,
    required this.description,
    required this.intensity,
    required this.category,
  });
}

/// Broad categories of friction.
enum FrictionCategory {
  /// Skips/misses cluster on particular weekdays.
  dayOfWeekPattern,

  /// Misses or skips correlate with specific energy levels.
  energyPattern,

  /// Misses or skips correlate with specific workload levels.
  workloadPattern,

  /// Misses cluster near the start of each week (Monday effect).
  weekStartPattern,

  /// Misses cluster near the end of each week (weekend drift).
  weekendDrift,

  /// High skip rate relative to completions (avoidance signal).
  highSkipRate,
}

/// The full friction map for a habit.
class FrictionMap {
  final String habitId;
  final List<FrictionSignal> signals;
  final int observationDays;

  /// Overall skip rate (skips / total due days with a log entry).
  final double skipRate;

  /// Whether there is enough data to surface friction patterns reliably.
  final bool isSufficient;

  static const int minimumObservations = 14;

  const FrictionMap({
    required this.habitId,
    required this.signals,
    required this.observationDays,
    required this.skipRate,
    required this.isSufficient,
  });
}

/// Analyses [HabitLog] history (optionally cross-referenced with
/// [DailyCheckIn] records) to produce a [FrictionMap].
///
/// All patterns are observational. The analyser describes what is observed
/// in the data — it does not prescribe solutions or make causal claims.
class FrictionAnalyser {
  const FrictionAnalyser();

  /// Compute the [FrictionMap] for [habit] from [logs].
  ///
  /// [checkIns] is optional — if provided, energy and workload patterns
  /// are cross-referenced against log dates.
  FrictionMap analyse({
    required Habit habit,
    required List<HabitLog> logs,
    List<DailyCheckIn> checkIns = const [],
    required DateTime today,
  }) {
    if (logs.isEmpty) {
      return FrictionMap(
        habitId: habit.id,
        signals: [],
        observationDays: 0,
        skipRate: 0.0,
        isSufficient: false,
      );
    }

    final loggedDays = logs.length;
    final skips = logs.where((l) => l.skipped).length;
    final skipRate = loggedDays == 0 ? 0.0 : skips / loggedDays;
    final isSufficient = loggedDays >= FrictionMap.minimumObservations;

    final signals = <FrictionSignal>[];

    if (isSufficient) {
      signals.addAll(_dayOfWeekSignals(logs, skipRate));
      signals.addAll(_weekStartSignal(logs));
      signals.addAll(_weekendDriftSignal(logs));
      signals.addAll(_highSkipSignal(skipRate, loggedDays));

      if (checkIns.isNotEmpty) {
        signals.addAll(_energyPatternSignals(logs, checkIns));
        signals.addAll(_workloadPatternSignals(logs, checkIns));
      }

      // Sort by descending intensity — most actionable first.
      signals.sort((a, b) => b.intensity.compareTo(a.intensity));
    }

    return FrictionMap(
      habitId: habit.id,
      signals: signals,
      observationDays: loggedDays,
      skipRate: skipRate,
      isSufficient: isSufficient,
    );
  }

  // ---------------------------------------------------------------------------
  // Pattern detectors
  // ---------------------------------------------------------------------------

  /// Identify weekdays where the miss/skip rate substantially exceeds the
  /// overall average.
  List<FrictionSignal> _dayOfWeekSignals(
      List<HabitLog> logs, double overallSkipRate) {
    // Bucket logs by weekday (1=Mon … 7=Sun).
    final buckets = <int, List<HabitLog>>{};
    for (final l in logs) {
      buckets.putIfAbsent(l.normalisedDate.weekday, () => []).add(l);
    }

    final signals = <FrictionSignal>[];
    for (final entry in buckets.entries) {
      final dayLogs = entry.value;
      if (dayLogs.length < 2) continue; // not enough to pattern-match

      final missedOrSkipped =
          dayLogs.where((l) => !l.completed || l.skipped).length;
      final dayRate = missedOrSkipped / dayLogs.length;

      // Surface only if this day is notably worse than average.
      if (dayRate >= 0.5 && dayRate >= overallSkipRate + 0.20) {
        final dayName = _weekdayName(entry.key);
        final intensity = ((dayRate - overallSkipRate) / (1.0 - overallSkipRate))
            .clamp(0.0, 1.0);
        signals.add(FrictionSignal(
          label: '$dayName friction',
          description:
              '${(dayRate * 100).round()}% of ${dayName}s were missed or '
              'skipped (${dayLogs.length} observations). '
              'This is ${((dayRate - overallSkipRate) * 100).round()} '
              'percentage points above your overall rate. '
              'Something about ${dayName}s may make this habit harder.',
          intensity: intensity,
          category: FrictionCategory.dayOfWeekPattern,
        ));
      }
    }
    return signals;
  }

  /// Monday-specific skip cluster (week-start friction).
  List<FrictionSignal> _weekStartSignal(List<HabitLog> logs) {
    final mondays = logs.where((l) => l.normalisedDate.weekday == 1).toList();
    if (mondays.length < 3) return [];

    final monMissed =
        mondays.where((l) => !l.completed || l.skipped).length;
    final monRate = monMissed / mondays.length;

    // Other days
    final others = logs.where((l) => l.normalisedDate.weekday != 1).toList();
    if (others.isEmpty) return [];
    final otherMissed =
        others.where((l) => !l.completed || l.skipped).length;
    final otherRate = otherMissed / others.length;

    final gap = monRate - otherRate;
    if (gap < 0.20) return [];

    return [
      FrictionSignal(
        label: 'Monday friction',
        description:
            'Mondays show a ${(monRate * 100).round()}% miss/skip rate '
            'vs ${(otherRate * 100).round()}% on other days '
            '(${mondays.length} Monday observations). '
            'Week-start resistance is common — consider a lighter Monday version.',
        intensity: (gap / 0.60).clamp(0.0, 1.0),
        category: FrictionCategory.weekStartPattern,
      )
    ];
  }

  /// Saturday/Sunday drift.
  List<FrictionSignal> _weekendDriftSignal(List<HabitLog> logs) {
    final weekendLogs =
        logs.where((l) => l.normalisedDate.weekday >= 6).toList();
    if (weekendLogs.length < 3) return [];

    final weekdayLogs =
        logs.where((l) => l.normalisedDate.weekday < 6).toList();
    if (weekdayLogs.isEmpty) return [];

    final weekendMissed =
        weekendLogs.where((l) => !l.completed || l.skipped).length;
    final weekdayMissed =
        weekdayLogs.where((l) => !l.completed || l.skipped).length;
    final weekendRate = weekendMissed / weekendLogs.length;
    final weekdayRate = weekdayMissed / weekdayLogs.length;

    final gap = weekendRate - weekdayRate;
    if (gap < 0.20) return [];

    return [
      FrictionSignal(
        label: 'Weekend drift',
        description:
            'Weekends show a ${(weekendRate * 100).round()}% miss/skip rate '
            'vs ${(weekdayRate * 100).round()}% on weekdays '
            '(${weekendLogs.length} weekend observations). '
            'Routines often break down on unstructured days.',
        intensity: (gap / 0.60).clamp(0.0, 1.0),
        category: FrictionCategory.weekendDrift,
      )
    ];
  }

  /// High overall skip rate signal.
  List<FrictionSignal> _highSkipSignal(double skipRate, int total) {
    if (skipRate < 0.25) return [];
    return [
      FrictionSignal(
        label: 'High skip rate',
        description:
            '${(skipRate * 100).round()}% of logged days were skipped '
            '($total total observations). '
            'A high skip rate may indicate the habit feels burdensome, '
            'is poorly timed, or conflicts with other commitments.',
        intensity: (skipRate / 0.6).clamp(0.0, 1.0),
        category: FrictionCategory.highSkipRate,
      )
    ];
  }

  /// Correlate low-energy check-in days with missed/skipped logs.
  List<FrictionSignal> _energyPatternSignals(
      List<HabitLog> logs, List<DailyCheckIn> checkIns) {
    final checkInMap = <DateTime, DailyCheckIn>{
      for (final ci in checkIns)
        DateTime(ci.date.year, ci.date.month, ci.date.day): ci,
    };

    final lowEnergyMisses = <HabitLog>[];
    final lowEnergyLogs = <HabitLog>[];

    for (final log in logs) {
      final ci = checkInMap[log.normalisedDate];
      if (ci?.energyLevel == EnergyLevel.low ||
          ci?.energyLevel == EnergyLevel.veryLow) {
        lowEnergyLogs.add(log);
        if (!log.completed || log.skipped) lowEnergyMisses.add(log);
      }
    }

    if (lowEnergyLogs.length < 3) return [];

    final lowEnergyMissRate = lowEnergyMisses.length / lowEnergyLogs.length;
    final overallMissed = logs.where((l) => !l.completed || l.skipped).length;
    final overallMissRate = overallMissed / logs.length;

    final gap = lowEnergyMissRate - overallMissRate;
    if (gap < 0.20) return [];

    return [
      FrictionSignal(
        label: 'Low-energy friction',
        description:
            'On days when you reported low or very low energy, '
            '${(lowEnergyMissRate * 100).round()}% of habit attempts were '
            'missed or skipped (${lowEnergyLogs.length} low-energy observations). '
            'This is ${(gap * 100).round()}pp above your overall rate. '
            'A minimum version on low-energy days may help maintain the pattern.',
        intensity: (gap / 0.60).clamp(0.0, 1.0),
        category: FrictionCategory.energyPattern,
      )
    ];
  }

  /// Correlate high-workload check-in days with missed/skipped logs.
  List<FrictionSignal> _workloadPatternSignals(
      List<HabitLog> logs, List<DailyCheckIn> checkIns) {
    final checkInMap = <DateTime, DailyCheckIn>{
      for (final ci in checkIns)
        DateTime(ci.date.year, ci.date.month, ci.date.day): ci,
    };

    final highWorkloadMisses = <HabitLog>[];
    final highWorkloadLogs = <HabitLog>[];

    for (final log in logs) {
      final ci = checkInMap[log.normalisedDate];
      if (ci?.workloadLevel == WorkloadLevel.heavy ||
          ci?.workloadLevel == WorkloadLevel.overwhelming) {
        highWorkloadLogs.add(log);
        if (!log.completed || log.skipped) highWorkloadMisses.add(log);
      }
    }

    if (highWorkloadLogs.length < 3) return [];

    final hwMissRate = highWorkloadMisses.length / highWorkloadLogs.length;
    final overallMissed = logs.where((l) => !l.completed || l.skipped).length;
    final overallMissRate = overallMissed / logs.length;

    final gap = hwMissRate - overallMissRate;
    if (gap < 0.20) return [];

    return [
      FrictionSignal(
        label: 'High-workload friction',
        description:
            'On heavy or overwhelming workload days, '
            '${(hwMissRate * 100).round()}% of habit attempts were '
            'missed or skipped (${highWorkloadLogs.length} observations). '
            'This is ${(gap * 100).round()}pp above your overall rate. '
            'A minimum version on demanding days may reduce friction.',
        intensity: (gap / 0.60).clamp(0.0, 1.0),
        category: FrictionCategory.workloadPattern,
      )
    ];
  }

  String _weekdayName(int weekday) {
    const names = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    return names[weekday] ?? 'day $weekday';
  }
}
