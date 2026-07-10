import 'dart:math';

import '../../domain/entities/habit_experiment.dart';

/// Assigns each experiment observation to intervention A or B.
///
/// Two strategies are supported:
/// - **Alternating**: strictly A, B, A, B, … based on the current observation
///   count. Deterministic — same count always yields the same assignment.
/// - **Randomised**: pseudo-random assignment seeded from the experiment id
///   and observation index. The seed is deterministic so the assignment is
///   reproducible (same experiment + same index = same arm).
///
/// Neither strategy is adaptive — arm probabilities remain 50/50 throughout
/// the experiment, avoiding Hawthorne effects from unequal exposure.
class AssignmentEngine {
  const AssignmentEngine();

  /// Assign an arm for the next observation in [experiment].
  ///
  /// [existingCount] is the number of observations already recorded.
  InterventionAssignment assign({
    required HabitExperiment experiment,
    required int existingCount,
  }) {
    switch (experiment.assignmentStrategy) {
      case AssignmentStrategy.alternating:
        return _alternating(existingCount);
      case AssignmentStrategy.randomised:
        return _randomised(experiment.id, existingCount);
    }
  }

  // ---------------------------------------------------------------------------
  // Strategies
  // ---------------------------------------------------------------------------

  /// Strict alternating: even index → A, odd index → B.
  InterventionAssignment _alternating(int index) =>
      index.isEven ? InterventionAssignment.a : InterventionAssignment.b;

  /// Deterministic pseudo-random assignment.
  ///
  /// Seed = hash of (experimentId + index). This is reproducible across
  /// sessions and devices without requiring server-side randomisation.
  InterventionAssignment _randomised(String experimentId, int index) {
    final seed = Object.hash(experimentId, index);
    final rng = Random(seed);
    return rng.nextBool() ? InterventionAssignment.a : InterventionAssignment.b;
  }

  /// Preview a full assignment sequence for [totalObservations].
  ///
  /// Used by the UI to show the planned arm order before the experiment starts.
  List<InterventionAssignment> previewSequence({
    required HabitExperiment experiment,
    required int totalObservations,
  }) {
    return List.generate(
      totalObservations,
      (i) => assign(experiment: experiment, existingCount: i),
    );
  }

  /// Verify that the assignment sequence is balanced (equal A and B counts)
  /// within ±1 observation for an even number of observations.
  ///
  /// Used internally for quality assurance in tests.
  bool isBalanced({
    required HabitExperiment experiment,
    required int totalObservations,
  }) {
    final seq = previewSequence(
        experiment: experiment, totalObservations: totalObservations);
    final aCount = seq.where((s) => s == InterventionAssignment.a).length;
    final bCount = totalObservations - aCount;
    return (aCount - bCount).abs() <= 1;
  }
}
