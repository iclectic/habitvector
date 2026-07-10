import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/entities/recovery_metrics.dart';

/// Computes [RecoveryMetrics] from a habit's log history.
///
/// "Recovery" is defined as: the user missed one or more consecutive days
/// then completed the habit again. The service classifies every miss event
/// and scores the subsequent response.
///
/// Definitions used throughout this class:
/// - **Miss event**: a due date with an explicit log where completed=false
///   and skipped=false.
/// - **Miss run**: one or more consecutive miss events.
/// - **Successful recovery**: a miss run followed by a completion within
///   [_recoveryWindowDays] days.
/// - **Lapse**: a miss run not followed by a completion within
///   [_lapseWindowDays] days.
class RecoveryAnalysisService {
  /// A miss run is considered recovered if the habit is completed within
  /// this many calendar days after the last miss.
  static const int _recoveryWindowDays = 2;

  /// A miss run is considered a lapse if not recovered within this window.
  static const int _lapseWindowDays = 7;

  const RecoveryAnalysisService();

  /// Calculate [RecoveryMetrics] for [habit] using [logs] sorted by date.
  ///
  /// [logs] should cover at least 90 days for reliable metrics.
  /// [today] is used as the ceiling date for open miss runs.
  RecoveryMetrics calculate({
    required Habit habit,
    required List<HabitLog> logs,
    required DateTime today,
  }) {
    if (logs.isEmpty) {
      return RecoveryMetrics(
        habitId: habit.id,
        observationCount: 0,
        isSufficient: false,
      );
    }

    // Sort ascending by date.
    final sorted = List<HabitLog>.from(logs)
      ..sort((a, b) => a.normalisedDate.compareTo(b.normalisedDate));

    final earliest = sorted.first.normalisedDate;

    // Build a map from date → log for O(1) lookup.
    final logMap = <DateTime, HabitLog>{
      for (final l in sorted) l.normalisedDate: l,
    };

    // Walk calendar from earliest to today, finding miss runs.
    final _MissRun? openRun = null;
    final missRuns = <_MissRun>[];
    _MissRun? current = openRun;

    DateTime d = earliest;
    while (!d.isAfter(today)) {
      if (!habit.isDueOn(d)) {
        d = d.add(const Duration(days: 1));
        continue;
      }

      final log = logMap[d];
      final isMiss = log != null && !log.completed && !log.skipped;
      final isCompletion = log != null && log.completed;

      if (isMiss) {
        // Extend the current miss run.
        if (current == null) {
          current = _MissRun(start: d);
        } else {
          current = _MissRun(start: current.start, closedEnd: d);
        }
      } else if (isCompletion) {
        // Completion closes the miss run as a successful recovery.
        if (current != null) {
          missRuns.add(current.closed(d));
          current = null;
        }
      }
      // No log (unknown) or skipped: leave current run open — do not close.

      d = d.add(const Duration(days: 1));
    }

    // Close any open run at today (not yet resolved).
    if (current != null) {
      missRuns.add(current);
    }

    if (missRuns.isEmpty) {
      return RecoveryMetrics(
        habitId: habit.id,
        observationCount: sorted.length,
        isSufficient: sorted.length >= RecoveryMetrics.minimumObservations,
      );
    }

    // Classify each miss run.
    int successfulRecoveries = 0;
    int lapsedAfterMiss = 0;
    final daysToRecover = <double>[];
    int oneMissEvents = 0;
    int oneMissRecoveries = 0;
    int twoOrMoreMissEvents = 0;
    int twoOrMoreMissRecoveries = 0;

    // Resilience trend: days-to-recover across time (for slope calculation).
    final recoverySeries = <(DateTime, double)>[];

    for (final run in missRuns) {
      final runLength = run.length;
      final isOneMiss = runLength == 1;

      if (run.recoveredOn != null) {
        final missEnd = run.closedEnd ?? today;
        final dtr = run.recoveredOn!.difference(missEnd).inDays.toDouble();
        final cappedDtr = dtr.clamp(1.0, _recoveryWindowDays.toDouble());
        daysToRecover.add(cappedDtr);
        recoverySeries.add((run.recoveredOn!, cappedDtr));
        successfulRecoveries++;

        if (isOneMiss) {
          oneMissEvents++;
          oneMissRecoveries++;
        } else {
          twoOrMoreMissEvents++;
          twoOrMoreMissRecoveries++;
        }
      } else if (run.recoveredOn == null && run.isResolvable(today, _lapseWindowDays)) {
        lapsedAfterMiss++;
        if (isOneMiss) {
          oneMissEvents++;
        } else {
          twoOrMoreMissEvents++;
        }
      }
      // Unresolvable (still within lapse window): exclude from counts.
    }

    final avgDaysToRecover = daysToRecover.isEmpty
        ? null
        : daysToRecover.reduce((a, b) => a + b) / daysToRecover.length;

    final afterOneMiss = oneMissEvents == 0
        ? null
        : oneMissRecoveries / oneMissEvents;

    final afterTwoOrMore = twoOrMoreMissEvents == 0
        ? null
        : twoOrMoreMissRecoveries / twoOrMoreMissEvents;

    final trend = _calculateResilienceTrend(recoverySeries);

    final observationCount = successfulRecoveries + lapsedAfterMiss;

    return RecoveryMetrics(
      habitId: habit.id,
      successfulRecoveries: successfulRecoveries,
      lapsedAfterMiss: lapsedAfterMiss,
      averageDaysToRecover: avgDaysToRecover,
      completionAfterOneMiss: afterOneMiss,
      completionAfterTwoOrMoreMisses: afterTwoOrMore,
      resilienceTrend: trend,
      observationCount: observationCount,
      isSufficient: observationCount >= RecoveryMetrics.minimumObservations,
    );
  }

  /// Linear slope of days-to-recover over time.
  ///
  /// Negative slope = recovering faster over time (good).
  /// Positive slope = taking longer to recover (declining resilience).
  /// Returns null when fewer than 3 data points.
  double? _calculateResilienceTrend(List<(DateTime, double)> series) {
    if (series.length < 3) return null;

    // Convert dates to x-axis as days-since-first-event.
    final origin = series.first.$1;
    final xs = series
        .map((p) => p.$1.difference(origin).inDays.toDouble())
        .toList();
    final ys = series.map((p) => p.$2).toList();
    final n = xs.length;

    final xMean = xs.reduce((a, b) => a + b) / n;
    final yMean = ys.reduce((a, b) => a + b) / n;

    double num = 0;
    double den = 0;
    for (int i = 0; i < n; i++) {
      num += (xs[i] - xMean) * (ys[i] - yMean);
      den += (xs[i] - xMean) * (xs[i] - xMean);
    }

    if (den == 0) return null;
    return num / den;
  }
}

// ---------------------------------------------------------------------------
// Internal helper
// ---------------------------------------------------------------------------

class _MissRun {
  final DateTime start;
  final DateTime? closedEnd;
  final DateTime? recoveredOn;

  const _MissRun({
    required this.start,
    this.closedEnd,
    this.recoveredOn,
  });

  /// Number of consecutive missed days in this run.
  int get length {
    if (closedEnd == null) return 1;
    return closedEnd!.difference(start).inDays + 1;
  }

  /// Close this run: [end] is the last miss day, [recoveredOn] is the first
  /// completion date after the run (may be null if not recovered).
  _MissRun closed(DateTime recoveredOn) => _MissRun(
        start: start,
        closedEnd: closedEnd ?? start,
        recoveredOn: recoveredOn,
      );

  /// Whether the run is old enough to be classified as a lapse.
  bool isResolvable(DateTime today, int lapseWindowDays) {
    final end = closedEnd ?? start;
    return today.difference(end).inDays >= lapseWindowDays;
  }
}
