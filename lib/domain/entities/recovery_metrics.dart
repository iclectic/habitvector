/// Recovery metrics for a single habit.
///
/// Recovery is the ability to resume a habit after missing one or more days.
/// These metrics complement streaks — they measure resilience rather than
/// consistency alone.
///
/// None of these values are presented as medical or psychological diagnoses.
/// The Recovery Score, if shown, must have a documented calculation.
class RecoveryMetrics {
  final String habitId;

  /// Total number of times the user missed then resumed within 2 days.
  final int successfulRecoveries;

  /// Total number of times the user missed then did not resume within 7 days.
  final int lapsedAfterMiss;

  /// Average number of days between a miss and the next completion.
  /// Null when [successfulRecoveries] == 0.
  final double? averageDaysToRecover;

  /// Completion rate on the day immediately after a single missed day.
  final double? completionAfterOneMiss;

  /// Completion rate within 3 days after two or more consecutive missed days.
  final double? completionAfterTwoOrMoreMisses;

  /// Trend: positive value means recovery is improving over time.
  /// Calculated as linear slope of recovery speed over the last 90 days.
  /// Null when insufficient data.
  final double? resilienceTrend;

  /// Number of observations used to calculate these metrics.
  final int observationCount;

  /// Whether there is sufficient data to display these metrics reliably.
  /// The minimum threshold is documented in [RecoveryMetrics.minimumObservations].
  final bool isSufficient;

  static const int minimumObservations = 5;

  const RecoveryMetrics({
    required this.habitId,
    this.successfulRecoveries = 0,
    this.lapsedAfterMiss = 0,
    this.averageDaysToRecover,
    this.completionAfterOneMiss,
    this.completionAfterTwoOrMoreMisses,
    this.resilienceTrend,
    this.observationCount = 0,
    this.isSufficient = false,
  });

  /// The proportion of misses that resulted in recovery within 2 days.
  double? get recoveryRate {
    final total = successfulRecoveries + lapsedAfterMiss;
    if (total == 0) return null;
    return successfulRecoveries / total;
  }

  RecoveryMetrics copyWith({
    String? habitId,
    int? successfulRecoveries,
    int? lapsedAfterMiss,
    double? averageDaysToRecover,
    bool clearAverageDays = false,
    double? completionAfterOneMiss,
    bool clearAfterOneMiss = false,
    double? completionAfterTwoOrMoreMisses,
    bool clearAfterTwoOrMore = false,
    double? resilienceTrend,
    bool clearResilienceTrend = false,
    int? observationCount,
    bool? isSufficient,
  }) {
    return RecoveryMetrics(
      habitId: habitId ?? this.habitId,
      successfulRecoveries: successfulRecoveries ?? this.successfulRecoveries,
      lapsedAfterMiss: lapsedAfterMiss ?? this.lapsedAfterMiss,
      averageDaysToRecover: clearAverageDays
          ? null
          : (averageDaysToRecover ?? this.averageDaysToRecover),
      completionAfterOneMiss: clearAfterOneMiss
          ? null
          : (completionAfterOneMiss ?? this.completionAfterOneMiss),
      completionAfterTwoOrMoreMisses: clearAfterTwoOrMore
          ? null
          : (completionAfterTwoOrMoreMisses ?? this.completionAfterTwoOrMoreMisses),
      resilienceTrend: clearResilienceTrend
          ? null
          : (resilienceTrend ?? this.resilienceTrend),
      observationCount: observationCount ?? this.observationCount,
      isSufficient: isSufficient ?? this.isSufficient,
    );
  }
}
