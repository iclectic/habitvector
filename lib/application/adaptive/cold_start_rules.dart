import '../../domain/entities/adaptive_recommendation.dart';
import '../../domain/entities/habit_versions.dart';
import 'context_feature_builder.dart';

/// Version identifier for this rule set.
const String kColdStartRulesVersion = 'cold-start-v1';

/// Minimum number of completed logs required before the personalised
/// scoring layer takes over from cold-start rules.
const int kMinObservationsForPersonalisation = 14;

/// Result of evaluating the cold-start rule set.
class ColdStartResult {
  final RecommendedAction action;
  final HabitVersionLevel? suggestedVersion;
  final double confidence;
  final String explanation;
  final RecommendedAction alternativeAction;
  final List<String> factorsUsed;
  final List<String> factorsMissing;

  const ColdStartResult({
    required this.action,
    this.suggestedVersion,
    required this.confidence,
    required this.explanation,
    required this.alternativeAction,
    required this.factorsUsed,
    required this.factorsMissing,
  });
}

/// Deterministic cold-start recommendation rules.
///
/// These rules are applied when the user has fewer than
/// [kMinObservationsForPersonalisation] observations. They are transparent,
/// documented, and fully testable.
///
/// Rule priority (highest to lowest):
///   1. Extended streak of consecutive misses → suggest recovery day
///   2. Low energy + high workload → suggest minimum version
///   3. Low energy only → suggest minimum version
///   4. High workload only → suggest minimum version
///   5. Time-limited day → suggest minimum version
///   6. Shift day with low energy → move to another time
///   7. Rest day → encourage stretch version
///   8. Default → complete standard
///
/// Confidence is intentionally conservative for cold-start — the system
/// does not claim high certainty without sufficient data.
class ColdStartRules {
  const ColdStartRules();

  /// Evaluate the rules and return a [ColdStartResult].
  ColdStartResult evaluate(ContextFeatures features) {
    final factorsUsed = List<String>.from(features.availableFactors);
    final factorsMissing = List<String>.from(features.missingFactors);

    // Rule 1: Extended consecutive misses — recommend a deliberate recovery day
    if (features.consecutiveMissesBeforeToday >= 3) {
      return ColdStartResult(
        action: RecommendedAction.scheduleRecoveryDay,
        confidence: _confidence(features, baseConfidence: 0.70),
        explanation: _buildExplanation(
          'You have missed this habit for '
          '${features.consecutiveMissesBeforeToday} days in a row. '
          'Rather than pushing for full completion after an extended break, '
          'a deliberate reset with a minimum version may be more sustainable.',
          features,
        ),
        alternativeAction: RecommendedAction.useMinimumVersion,
        factorsUsed: factorsUsed,
        factorsMissing: factorsMissing,
      );
    }

    // Rule 2: Low energy AND high workload → minimum version
    if (features.isLowEnergy && features.isHighWorkload) {
      return ColdStartResult(
        action: RecommendedAction.useMinimumVersion,
        suggestedVersion: HabitVersionLevel.minimum,
        confidence: _confidence(features, baseConfidence: 0.68),
        explanation: _buildExplanation(
          'You have reported both low energy and a heavy workload today. '
          'A shorter version of this habit is more likely to be completed '
          'and still counts as maintaining your pattern.',
          features,
        ),
        alternativeAction: RecommendedAction.leavePlanUnchanged,
        factorsUsed: factorsUsed,
        factorsMissing: factorsMissing,
      );
    }

    // Rule 3: Low energy only → minimum version
    if (features.isLowEnergy) {
      return ColdStartResult(
        action: RecommendedAction.useMinimumVersion,
        suggestedVersion: HabitVersionLevel.minimum,
        confidence: _confidence(features, baseConfidence: 0.62),
        explanation: _buildExplanation(
          'Your reported energy level is low today. '
          'A shorter version of this habit gives you the best chance of '
          'completing something rather than nothing.',
          features,
        ),
        alternativeAction: RecommendedAction.leavePlanUnchanged,
        factorsUsed: factorsUsed,
        factorsMissing: factorsMissing,
      );
    }

    // Rule 4: High workload only → minimum version
    if (features.isHighWorkload) {
      return ColdStartResult(
        action: RecommendedAction.useMinimumVersion,
        suggestedVersion: HabitVersionLevel.minimum,
        confidence: _confidence(features, baseConfidence: 0.60),
        explanation: _buildExplanation(
          'Your reported workload is heavy today. '
          'A minimum version of this habit keeps the pattern going '
          'without overloading an already demanding day.',
          features,
        ),
        alternativeAction: RecommendedAction.leavePlanUnchanged,
        factorsUsed: factorsUsed,
        factorsMissing: factorsMissing,
      );
    }

    // Rule 5: Time-limited (< 15 minutes available) → minimum version
    if (features.isTimeLimited) {
      return ColdStartResult(
        action: RecommendedAction.useMinimumVersion,
        suggestedVersion: HabitVersionLevel.minimum,
        confidence: _confidence(features, baseConfidence: 0.65),
        explanation: _buildExplanation(
          'You have reported less than 15 minutes available today. '
          'A minimum version keeps the habit alive within the time you have.',
          features,
        ),
        alternativeAction: RecommendedAction.moveToAnotherTime,
        factorsUsed: factorsUsed,
        factorsMissing: factorsMissing,
      );
    }

    // Rule 6: Active shift day + low confidence → move to another time
    if (features.isShiftDay &&
        features.confidenceScore != null &&
        features.confidenceScore! < 0.4) {
      return ColdStartResult(
        action: RecommendedAction.moveToAnotherTime,
        confidence: _confidence(features, baseConfidence: 0.55),
        explanation: _buildExplanation(
          'You have a shift today and reported low confidence in completing '
          'this habit. Attempting it before or after your shift window '
          'may be more achievable.',
          features,
        ),
        alternativeAction: RecommendedAction.useMinimumVersion,
        factorsUsed: factorsUsed,
        factorsMissing: factorsMissing,
      );
    }

    // Rule 7: Rest day → encourage stretch
    if (features.isRestDay &&
        features.completionsLast7Days >= 3 &&
        !features.isLowEnergy) {
      return ColdStartResult(
        action: RecommendedAction.attemptStretchVersion,
        suggestedVersion: HabitVersionLevel.stretch,
        confidence: _confidence(features, baseConfidence: 0.58),
        explanation: _buildExplanation(
          'Today is a rest day and you have completed this habit '
          '${features.completionsLast7Days} times in the last week. '
          'A stretch version today could extend your progress on a day '
          'when you have more time.',
          features,
        ),
        alternativeAction: RecommendedAction.completeStandard,
        factorsUsed: factorsUsed,
        factorsMissing: factorsMissing,
      );
    }

    // Rule 8: After 1–2 consecutive misses → standard with encouragement
    if (features.consecutiveMissesBeforeToday == 1 ||
        features.consecutiveMissesBeforeToday == 2) {
      return ColdStartResult(
        action: RecommendedAction.completeStandard,
        suggestedVersion: HabitVersionLevel.standard,
        confidence: _confidence(features, baseConfidence: 0.60),
        explanation: _buildExplanation(
          'You missed this habit yesterday'
          '${features.consecutiveMissesBeforeToday == 2 ? " and the day before" : ""}. '
          'Completing it today restores your pattern — the standard version '
          'is a good target.',
          features,
        ),
        alternativeAction: RecommendedAction.useMinimumVersion,
        factorsUsed: factorsUsed,
        factorsMissing: factorsMissing,
      );
    }

    // Default: complete standard
    return ColdStartResult(
      action: RecommendedAction.completeStandard,
      suggestedVersion: HabitVersionLevel.standard,
      confidence: _confidence(features, baseConfidence: 0.55),
      explanation: _buildExplanation(
        'No specific conditions suggest a change today. '
        'Completing the standard version of this habit is the recommended path.',
        features,
      ),
      alternativeAction: RecommendedAction.leavePlanUnchanged,
      factorsUsed: factorsUsed,
      factorsMissing: factorsMissing,
    );
  }

  /// Adjust confidence based on how much context is available.
  ///
  /// Cold-start confidence is inherently limited. Available context factors
  /// raise confidence slightly; missing context lowers it.
  double _confidence(
    ContextFeatures features, {
    required double baseConfidence,
  }) {
    double c = baseConfidence;

    // More available context → slightly more reliable
    final available = features.availableFactors.length;
    if (available >= 3) {
      c += 0.05;
    } else if (available == 0) {
      c -= 0.10;
    }

    // History available → slightly more reliable
    if (features.recentLogs.isNotEmpty) {
      c += 0.03;
    }

    return c.clamp(0.30, 0.75);
  }

  /// Append context qualifier to explanation when data is sparse.
  String _buildExplanation(String core, ContextFeatures features) {
    if (features.availableFactors.isEmpty) {
      return '$core No daily check-in was available, so this suggestion '
          'is based on general patterns only.';
    }
    return core;
  }
}
