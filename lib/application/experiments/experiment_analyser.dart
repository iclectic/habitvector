import '../../domain/entities/habit_experiment.dart';

/// Strength of evidence from an experiment.
///
/// Values are deliberately conservative and observational — the system
/// never claims causal proof from N-of-1 data.
enum EvidenceStrength {
  /// Fewer than [ExperimentAnalyser.minObservationsPerArm] observations
  /// per arm. Results should not be acted on.
  insufficient,

  /// Enough observations but effect is small or unclear.
  weak,

  /// Meaningful difference between arms with adequate sample.
  moderate,

  /// Large, consistent difference with a sufficient sample.
  strong,
}

/// Results from analysing one arm of an experiment.
class ArmResult {
  final InterventionAssignment arm;
  final int observations;
  final int completions;
  final double completionRate;

  const ArmResult({
    required this.arm,
    required this.observations,
    required this.completions,
    required this.completionRate,
  });
}

/// Full experiment analysis snapshot.
class ExperimentAnalysis {
  final HabitExperiment experiment;
  final ArmResult armA;
  final ArmResult armB;
  final EvidenceStrength evidenceStrength;

  /// Qualified observational conclusion — never claims causation.
  final String conclusion;

  /// Whether the experiment has met its minimum observation target.
  final bool hasMinimumObservations;

  /// Arm with the higher completion rate (null when tied or insufficient).
  final InterventionAssignment? preferredArm;

  /// Absolute difference in completion rates (A − B). Positive means A led.
  final double rateGap;

  const ExperimentAnalysis({
    required this.experiment,
    required this.armA,
    required this.armB,
    required this.evidenceStrength,
    required this.conclusion,
    required this.hasMinimumObservations,
    this.preferredArm,
    required this.rateGap,
  });
}

/// Analyses [ExperimentObservation] records and produces an
/// [ExperimentAnalysis].
///
/// Language rules:
/// - Never use "caused", "proved", or "significantly better".
/// - Use "associated with", "observed", "tended to", "in this data".
/// - Always qualify with sample size.
class ExperimentAnalyser {
  /// Minimum observations per arm before results are considered actionable.
  static const int minObservationsPerArm = 5;

  /// Minimum absolute rate gap to report a "moderate" evidence finding.
  static const double moderateGapThreshold = 0.15;

  /// Minimum absolute rate gap to report a "strong" evidence finding.
  static const double strongGapThreshold = 0.30;

  const ExperimentAnalyser();

  /// Produce an [ExperimentAnalysis] from [observations].
  ExperimentAnalysis analyse({
    required HabitExperiment experiment,
    required List<ExperimentObservation> observations,
  }) {
    final aObs =
        observations.where((o) => o.assignment == InterventionAssignment.a).toList();
    final bObs =
        observations.where((o) => o.assignment == InterventionAssignment.b).toList();

    final armA = _buildArmResult(InterventionAssignment.a, aObs);
    final armB = _buildArmResult(InterventionAssignment.b, bObs);

    final hasMin =
        armA.observations >= minObservationsPerArm &&
        armB.observations >= minObservationsPerArm;

    final totalObs = observations.length;
    final hasMinTotal = totalObs >= experiment.minimumObservations;

    final rateGap = armA.completionRate - armB.completionRate;
    final absGap = rateGap.abs();

    final EvidenceStrength strength;
    final InterventionAssignment? preferred;

    if (!hasMin || !hasMinTotal) {
      strength = EvidenceStrength.insufficient;
      preferred = null;
    } else if (absGap >= strongGapThreshold) {
      strength = EvidenceStrength.strong;
      preferred = _preferredArm(armA, armB);
    } else if (absGap >= moderateGapThreshold) {
      strength = EvidenceStrength.moderate;
      preferred = _preferredArm(armA, armB);
    } else {
      strength = EvidenceStrength.weak;
      preferred = null; // Gap too small to recommend one arm
    }

    final conclusion = _buildConclusion(
      experiment: experiment,
      armA: armA,
      armB: armB,
      strength: strength,
      preferred: preferred,
      rateGap: rateGap,
      totalObs: totalObs,
    );

    return ExperimentAnalysis(
      experiment: experiment,
      armA: armA,
      armB: armB,
      evidenceStrength: strength,
      conclusion: conclusion,
      hasMinimumObservations: hasMin && hasMinTotal,
      preferredArm: preferred,
      rateGap: rateGap,
    );
  }

  ArmResult _buildArmResult(
      InterventionAssignment arm, List<ExperimentObservation> obs) {
    final completions = obs.where((o) => o.completed).length;
    final rate = obs.isEmpty ? 0.0 : completions / obs.length;
    return ArmResult(
      arm: arm,
      observations: obs.length,
      completions: completions,
      completionRate: rate,
    );
  }

  InterventionAssignment? _preferredArm(ArmResult a, ArmResult b) {
    if (a.completionRate > b.completionRate) return InterventionAssignment.a;
    if (b.completionRate > a.completionRate) return InterventionAssignment.b;
    return null;
  }

  String _buildConclusion({
    required HabitExperiment experiment,
    required ArmResult armA,
    required ArmResult armB,
    required EvidenceStrength strength,
    required InterventionAssignment? preferred,
    required double rateGap,
    required int totalObs,
  }) {
    if (strength == EvidenceStrength.insufficient) {
      final missing = experiment.minimumObservations - totalObs;
      if (missing > 0) {
        return 'Not enough data yet. $missing more observations are needed '
            'before results can be interpreted. '
            '(A: ${armA.observations} obs, B: ${armB.observations} obs)';
      }
      return 'Each arm needs at least $minObservationsPerArm observations. '
          '(A: ${armA.observations}, B: ${armB.observations})';
    }

    final aRate = _pct(armA.completionRate);
    final bRate = _pct(armB.completionRate);
    final gapStr = _pct(rateGap.abs());
    final preferredLabel = preferred == InterventionAssignment.a
        ? '"${experiment.interventionA}"'
        : '"${experiment.interventionB}"';

    if (strength == EvidenceStrength.weak || preferred == null) {
      return 'In this $totalObs-observation experiment, '
          '"${experiment.interventionA}" was associated with a $aRate% '
          'completion rate and "${experiment.interventionB}" with $bRate%. '
          'The $gapStr% difference is small and may reflect normal variation '
          'rather than a meaningful pattern.';
    }

    final strengthWord =
        strength == EvidenceStrength.strong ? 'a consistent' : 'a noticeable';

    return 'In this $totalObs-observation experiment, $preferredLabel '
        'was associated with $strengthWord difference in completion '
        '($aRate% vs $bRate%, a $gapStr% gap). '
        'This is an observational pattern — other factors may have '
        'contributed. Consider whether this aligns with your experience '
        'before adopting it as your default approach.';
  }

  String _pct(double rate) => (rate * 100).toStringAsFixed(1);
}
