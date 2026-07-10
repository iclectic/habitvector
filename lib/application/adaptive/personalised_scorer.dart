import '../../domain/entities/adaptive_recommendation.dart';
import '../../domain/entities/daily_check_in.dart';
import '../../domain/entities/habit_versions.dart';
import '../../domain/entities/recovery_metrics.dart';
import 'cold_start_rules.dart';
import 'context_feature_builder.dart';

/// Version identifier for the personalised scoring layer.
const String kPersonalisedScorerVersion = 'personalised-v1';

/// Personalised recommendation scorer used once the user has accumulated
/// [kMinObservationsForPersonalisation] completed logs for a habit.
///
/// ## Approach
/// Rather than a black-box model, this uses an **interpretable weighted score**
/// with documented weights and thresholds. Each feature contributes a named,
/// visible score. The overall score maps to a [RecommendedAction] and both
/// the weights and the feature contributions appear in the explanation.
///
/// This is intentionally simpler than a full Bayesian model — the goal is
/// explainability and user trust, not maximum predictive accuracy.
///
/// ## Feature weights (0.0 – 1.0, sum to 1.0)
/// | Feature                      | Weight |
/// |------------------------------|--------|
/// | Energy level                 | 0.25   |
/// | Workload level               | 0.20   |
/// | Recent completion rate (7d)  | 0.20   |
/// | Recovery rate                | 0.15   |
/// | Time available               | 0.10   |
/// | Day type                     | 0.10   |
///
/// Missing features contribute a neutral score (0.5) so the engine degrades
/// gracefully rather than failing when context is absent.
///
/// ## Score → Action mapping
/// | Score range   | Action                    |
/// |---------------|---------------------------|
/// | 0.75 – 1.00   | attemptStretchVersion     |
/// | 0.55 – 0.74   | completeStandard          |
/// | 0.35 – 0.54   | useMinimumVersion         |
/// | 0.00 – 0.34   | scheduleRecoveryDay       |
class PersonalisedScorer {
  const PersonalisedScorer();

  /// Evaluate personalised features and return a [ColdStartResult]-compatible
  /// struct that the [RecommendationEngine] can use directly.
  ColdStartResult evaluate(
    ContextFeatures features, {
    RecoveryMetrics? recovery,
  }) {
    final scores = _FeatureScores(
      energy: _scoreEnergy(features.energyLevel),
      workload: _scoreWorkload(features.workloadLevel),
      recentRate: _scoreRecentRate(
          features.completionsLast7Days, features.recentLogs.length),
      recoveryRate: _scoreRecovery(recovery?.recoveryRate),
      timeAvailable: _scoreTime(features.availableMinutes),
      dayType: _scoreDayType(features.dayType),
    );

    final total = scores.weighted;

    final action = _actionForScore(total, features);
    final version = _versionForAction(action);
    final alt = _alternativeFor(action);
    final confidence = _confidenceForScore(total, features);
    final explanation = _buildExplanation(total, scores, features, recovery);

    final factorsUsed = List<String>.from(features.availableFactors);
    if (recovery != null && recovery.isSufficient) {
      factorsUsed.add('recovery_rate');
    }

    return ColdStartResult(
      action: action,
      suggestedVersion: version,
      confidence: confidence,
      explanation: explanation,
      alternativeAction: alt,
      factorsUsed: factorsUsed,
      factorsMissing: features.missingFactors,
    );
  }

  // ---------------------------------------------------------------------------
  // Feature scorers — each returns 0.0 (worst) to 1.0 (best)
  // ---------------------------------------------------------------------------

  double _scoreEnergy(EnergyLevel? level) {
    if (level == null) return 0.5; // neutral
    switch (level) {
      case EnergyLevel.veryLow:
        return 0.05;
      case EnergyLevel.low:
        return 0.25;
      case EnergyLevel.moderate:
        return 0.55;
      case EnergyLevel.high:
        return 0.80;
      case EnergyLevel.veryHigh:
        return 1.00;
    }
  }

  double _scoreWorkload(WorkloadLevel? level) {
    if (level == null) return 0.5; // neutral
    switch (level) {
      case WorkloadLevel.overwhelming:
        return 0.05;
      case WorkloadLevel.heavy:
        return 0.25;
      case WorkloadLevel.moderate:
        return 0.55;
      case WorkloadLevel.light:
        return 1.00;
    }
  }

  /// Recent 7-day completion rate compared to how many due days there were.
  double _scoreRecentRate(int completions7d, int totalLogs) {
    if (totalLogs == 0) return 0.5;
    // Cap at 7 possible days.
    final possible = totalLogs.clamp(1, 7);
    return (completions7d / possible).clamp(0.0, 1.0);
  }

  double _scoreRecovery(double? recoveryRate) {
    if (recoveryRate == null) return 0.5; // no data → neutral
    return recoveryRate.clamp(0.0, 1.0);
  }

  double _scoreTime(int? minutes) {
    if (minutes == null) return 0.5;
    if (minutes < 10) return 0.05;
    if (minutes < 20) return 0.30;
    if (minutes < 40) return 0.65;
    return 1.00;
  }

  double _scoreDayType(DayType? dayType) {
    if (dayType == null) return 0.5;
    switch (dayType) {
      case DayType.restDay:
        return 0.85; // more flexibility
      case DayType.workday:
        return 0.55;
      case DayType.studyDay:
        return 0.50;
      case DayType.shiftDay:
        return 0.35;
      case DayType.other:
        return 0.50;
    }
  }

  // ---------------------------------------------------------------------------
  // Score → Action mapping
  // ---------------------------------------------------------------------------

  RecommendedAction _actionForScore(
      double score, ContextFeatures features) {
    // Override: extended consecutive misses always → recovery, regardless of score.
    if (features.consecutiveMissesBeforeToday >= 3) {
      return RecommendedAction.scheduleRecoveryDay;
    }

    if (score >= 0.75) return RecommendedAction.attemptStretchVersion;
    if (score >= 0.55) return RecommendedAction.completeStandard;
    if (score >= 0.35) return RecommendedAction.useMinimumVersion;
    return RecommendedAction.scheduleRecoveryDay;
  }

  HabitVersionLevel? _versionForAction(RecommendedAction action) {
    switch (action) {
      case RecommendedAction.attemptStretchVersion:
        return HabitVersionLevel.stretch;
      case RecommendedAction.completeStandard:
        return HabitVersionLevel.standard;
      case RecommendedAction.useMinimumVersion:
        return HabitVersionLevel.minimum;
      default:
        return null;
    }
  }

  RecommendedAction _alternativeFor(RecommendedAction action) {
    switch (action) {
      case RecommendedAction.attemptStretchVersion:
        return RecommendedAction.completeStandard;
      case RecommendedAction.completeStandard:
        return RecommendedAction.useMinimumVersion;
      case RecommendedAction.useMinimumVersion:
        return RecommendedAction.leavePlanUnchanged;
      case RecommendedAction.scheduleRecoveryDay:
        return RecommendedAction.useMinimumVersion;
      default:
        return RecommendedAction.leavePlanUnchanged;
    }
  }

  /// Confidence is higher when more features are available and when the score
  /// is decisive (far from the thresholds). Clamped to [0.45, 0.90] to signal
  /// that even personalised scoring is imperfect.
  double _confidenceForScore(double score, ContextFeatures features) {
    // Base: distance from the nearest threshold.
    final thresholds = [0.35, 0.55, 0.75];
    final minDistance =
        thresholds.map((t) => (score - t).abs()).reduce((a, b) => a < b ? a : b);
    final decisiveness = (minDistance / 0.20).clamp(0.0, 1.0);

    // Context richness bonus.
    final contextBonus = (features.availableFactors.length / 8.0).clamp(0.0, 0.15);

    final c = 0.50 + decisiveness * 0.30 + contextBonus;
    return c.clamp(0.45, 0.90);
  }

  // ---------------------------------------------------------------------------
  // Explanation builder
  // ---------------------------------------------------------------------------

  String _buildExplanation(
    double total,
    _FeatureScores scores,
    ContextFeatures features,
    RecoveryMetrics? recovery,
  ) {
    final buf = StringBuffer();

    buf.write('Personalised score: ${(total * 100).round()}/100. ');

    // Top driver: the highest-contributing feature.
    final contributions = <String, double>{
      'energy': scores.energy * _FeatureScores.wEnergy,
      'workload': scores.workload * _FeatureScores.wWorkload,
      'recent completion rate': scores.recentRate * _FeatureScores.wRecentRate,
      'recovery rate': scores.recoveryRate * _FeatureScores.wRecovery,
      'available time': scores.timeAvailable * _FeatureScores.wTime,
      'day type': scores.dayType * _FeatureScores.wDayType,
    };

    final topDriver = contributions.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    final bottomDriver = contributions.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;

    buf.write('Strongest driver: $topDriver. ');

    if (scores.energy < 0.3 && features.energyLevel != null) {
      buf.write('Low energy is the main constraint today. ');
    }
    if (scores.workload < 0.3 && features.workloadLevel != null) {
      buf.write('Heavy workload is reducing today\'s capacity. ');
    }
    if (scores.recentRate >= 0.7) {
      buf.write('Strong recent completion streak supports a higher goal. ');
    }
    if (recovery != null &&
        recovery.isSufficient &&
        recovery.recoveryRate != null) {
      final rr = (recovery.recoveryRate! * 100).round();
      buf.write('Your recovery rate is $rr% — ');
      if (recovery.recoveryRate! >= 0.7) {
        buf.write('you bounce back reliably after a miss. ');
      } else {
        buf.write('misses sometimes extend into lapses. ');
      }
    }
    if (features.consecutiveMissesBeforeToday >= 3) {
      buf.write(
          'After ${features.consecutiveMissesBeforeToday} consecutive misses, '
          'a deliberate reset is recommended over pushing for full completion. ');
    }

    // Note missing data.
    if (features.availableFactors.length < 3) {
      buf.write(
          'Confidence would increase with a daily check-in. ');
    }

    // Suppress bottomDriver note when it is neutral (no data).
    if (bottomDriver == 'energy' && features.energyLevel == null) {
      // skip
    } else if (bottomDriver == 'available time' &&
        features.availableMinutes == null) {
      // skip
    } else {
      buf.write('Lowest factor: $bottomDriver.');
    }

    return buf.toString().trim();
  }
}

// ---------------------------------------------------------------------------
// Internal weight constants and weighted score
// ---------------------------------------------------------------------------

class _FeatureScores {
  static const double wEnergy = 0.25;
  static const double wWorkload = 0.20;
  static const double wRecentRate = 0.20;
  static const double wRecovery = 0.15;
  static const double wTime = 0.10;
  static const double wDayType = 0.10;

  final double energy;
  final double workload;
  final double recentRate;
  final double recoveryRate;
  final double timeAvailable;
  final double dayType;

  const _FeatureScores({
    required this.energy,
    required this.workload,
    required this.recentRate,
    required this.recoveryRate,
    required this.timeAvailable,
    required this.dayType,
  });

  double get weighted =>
      energy * wEnergy +
      workload * wWorkload +
      recentRate * wRecentRate +
      recoveryRate * wRecovery +
      timeAvailable * wTime +
      dayType * wDayType;
}
