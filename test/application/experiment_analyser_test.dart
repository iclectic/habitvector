import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/application/experiments/experiment_analyser.dart';
import 'package:habit_flow/domain/entities/habit_experiment.dart';

void main() {
  const analyser = ExperimentAnalyser();

  HabitExperiment experiment({int minimumObservations = 10}) =>
      HabitExperiment(
        id: 'exp1',
        habitId: 'h1',
        title: 'Morning vs Evening',
        hypothesis: 'Morning attempt has higher completion',
        primaryOutcome: 'completion rate',
        interventionA: 'Morning',
        interventionB: 'Evening',
        assignmentStrategy: AssignmentStrategy.alternating,
        durationDays: 30,
        minimumObservations: minimumObservations,
        startDate: DateTime(2024, 6, 1),
        status: ExperimentStatus.active,
        createdAt: DateTime(2024, 6, 1),
        updatedAt: DateTime(2024, 6, 1),
      );

  ExperimentObservation obs(
    int index,
    InterventionAssignment arm,
    bool completed,
  ) =>
      ExperimentObservation(
        id: 'obs$index',
        experimentId: 'exp1',
        habitId: 'h1',
        date: DateTime(2024, 6, 1 + index),
        assignment: arm,
        completed: completed,
        createdAt: DateTime(2024, 6, 1 + index),
      );

  // ---------------------------------------------------------------------------
  // Insufficient data
  // ---------------------------------------------------------------------------
  group('ExperimentAnalyser — insufficient data', () {
    test('no observations → insufficient', () {
      final result =
          analyser.analyse(experiment: experiment(), observations: []);
      expect(result.evidenceStrength, EvidenceStrength.insufficient);
      expect(result.hasMinimumObservations, isFalse);
      expect(result.preferredArm, isNull);
    });

    test('fewer than minObservationsPerArm per arm → insufficient', () {
      final observations = [
        obs(0, InterventionAssignment.a, true),
        obs(1, InterventionAssignment.b, false),
        obs(2, InterventionAssignment.a, true),
        obs(3, InterventionAssignment.b, true),
      ];
      final result = analyser.analyse(
          experiment: experiment(), observations: observations);
      expect(result.evidenceStrength, EvidenceStrength.insufficient);
    });

    test('insufficient explanation mentions observations needed', () {
      final result =
          analyser.analyse(experiment: experiment(), observations: []);
      expect(result.conclusion, contains('observations are needed'));
    });
  });

  // ---------------------------------------------------------------------------
  // Weak evidence (small gap)
  // ---------------------------------------------------------------------------
  group('ExperimentAnalyser — weak evidence', () {
    test('small gap between arms → weak', () {
      // A: 6/10 (60%), B: 5/10 (50%) → 10% gap < 15% threshold
      final observations = [
        for (int i = 0; i < 6; i++) obs(i, InterventionAssignment.a, true),
        for (int i = 6; i < 10; i++) obs(i, InterventionAssignment.a, false),
        for (int i = 10; i < 15; i++) obs(i, InterventionAssignment.b, true),
        for (int i = 15; i < 20; i++) obs(i, InterventionAssignment.b, false),
      ];
      final result = analyser.analyse(
          experiment: experiment(), observations: observations);
      expect(result.evidenceStrength, EvidenceStrength.weak);
      expect(result.preferredArm, isNull); // gap too small
    });
  });

  // ---------------------------------------------------------------------------
  // Moderate evidence
  // ---------------------------------------------------------------------------
  group('ExperimentAnalyser — moderate evidence', () {
    test('20% gap → moderate, identifies preferred arm', () {
      // A: 8/10 (80%), B: 6/10 (60%) → 20% gap ≥ moderate threshold
      final observations = [
        for (int i = 0; i < 8; i++) obs(i, InterventionAssignment.a, true),
        for (int i = 8; i < 10; i++) obs(i, InterventionAssignment.a, false),
        for (int i = 10; i < 16; i++) obs(i, InterventionAssignment.b, true),
        for (int i = 16; i < 20; i++) obs(i, InterventionAssignment.b, false),
      ];
      final result = analyser.analyse(
          experiment: experiment(), observations: observations);
      expect(result.evidenceStrength, EvidenceStrength.moderate);
      expect(result.preferredArm, InterventionAssignment.a);
    });
  });

  // ---------------------------------------------------------------------------
  // Strong evidence
  // ---------------------------------------------------------------------------
  group('ExperimentAnalyser — strong evidence', () {
    test('35% gap → strong, identifies preferred arm', () {
      // A: 9/10 (90%), B: 5/10 (50%) → 40% gap ≥ strong threshold
      final observations = [
        for (int i = 0; i < 9; i++) obs(i, InterventionAssignment.a, true),
        for (int i = 9; i < 10; i++) obs(i, InterventionAssignment.a, false),
        for (int i = 10; i < 15; i++) obs(i, InterventionAssignment.b, true),
        for (int i = 15; i < 20; i++) obs(i, InterventionAssignment.b, false),
      ];
      final result = analyser.analyse(
          experiment: experiment(), observations: observations);
      expect(result.evidenceStrength, EvidenceStrength.strong);
      expect(result.preferredArm, InterventionAssignment.a);
    });

    test('B performs better → B preferred', () {
      // A: 5/10 (50%), B: 9/10 (90%)
      final observations = [
        for (int i = 0; i < 5; i++) obs(i, InterventionAssignment.a, true),
        for (int i = 5; i < 10; i++) obs(i, InterventionAssignment.a, false),
        for (int i = 10; i < 19; i++) obs(i, InterventionAssignment.b, true),
        obs(19, InterventionAssignment.b, false),
      ];
      final result = analyser.analyse(
          experiment: experiment(), observations: observations);
      expect(result.preferredArm, InterventionAssignment.b);
    });
  });

  // ---------------------------------------------------------------------------
  // Arm results
  // ---------------------------------------------------------------------------
  group('ExperimentAnalyser — arm results', () {
    test('arm completion rates are correct', () {
      // A: 3/5, B: 4/5
      final observations = [
        obs(0, InterventionAssignment.a, true),
        obs(1, InterventionAssignment.a, true),
        obs(2, InterventionAssignment.a, true),
        obs(3, InterventionAssignment.a, false),
        obs(4, InterventionAssignment.a, false),
        obs(5, InterventionAssignment.b, true),
        obs(6, InterventionAssignment.b, true),
        obs(7, InterventionAssignment.b, true),
        obs(8, InterventionAssignment.b, true),
        obs(9, InterventionAssignment.b, false),
      ];
      final result = analyser.analyse(
          experiment: experiment(), observations: observations);
      expect(result.armA.completionRate, closeTo(0.6, 0.001));
      expect(result.armB.completionRate, closeTo(0.8, 0.001));
      expect(result.armA.observations, 5);
      expect(result.armB.observations, 5);
    });

    test('rateGap is armA minus armB', () {
      final observations = [
        for (int i = 0; i < 8; i++) obs(i, InterventionAssignment.a, true),
        for (int i = 8; i < 10; i++) obs(i, InterventionAssignment.a, false),
        for (int i = 10; i < 16; i++) obs(i, InterventionAssignment.b, true),
        for (int i = 16; i < 20; i++) obs(i, InterventionAssignment.b, false),
      ];
      final result = analyser.analyse(
          experiment: experiment(), observations: observations);
      expect(result.rateGap, closeTo(0.80 - 0.60, 0.001));
    });
  });

  // ---------------------------------------------------------------------------
  // Conclusion language
  // ---------------------------------------------------------------------------
  group('ExperimentAnalyser — conclusion language', () {
    test('conclusion never uses causal language', () {
      final observations = [
        for (int i = 0; i < 9; i++) obs(i, InterventionAssignment.a, true),
        for (int i = 9; i < 10; i++) obs(i, InterventionAssignment.a, false),
        for (int i = 10; i < 15; i++) obs(i, InterventionAssignment.b, true),
        for (int i = 15; i < 20; i++) obs(i, InterventionAssignment.b, false),
      ];
      final result = analyser.analyse(
          experiment: experiment(), observations: observations);
      final conclusion = result.conclusion.toLowerCase();
      expect(conclusion, isNot(contains('caused')));
      expect(conclusion, isNot(contains('proves')));
      expect(conclusion, isNot(contains('significantly better')));
    });

    test('conclusion mentions observational qualifier', () {
      final observations = [
        for (int i = 0; i < 9; i++) obs(i, InterventionAssignment.a, true),
        obs(9, InterventionAssignment.a, false),
        for (int i = 10; i < 15; i++) obs(i, InterventionAssignment.b, true),
        for (int i = 15; i < 20; i++) obs(i, InterventionAssignment.b, false),
      ];
      final result = analyser.analyse(
          experiment: experiment(), observations: observations);
      expect(result.conclusion, contains('observational'));
    });

    test('conclusion is non-empty for all evidence levels', () {
      for (final obs in [
        <ExperimentObservation>[],
        [
          ExperimentObservation(
            id: 'o1',
            experimentId: 'exp1',
            habitId: 'h1',
            date: DateTime(2024, 6, 1),
            assignment: InterventionAssignment.a,
            completed: true,
            createdAt: DateTime(2024, 6, 1),
          ),
        ],
      ]) {
        final result = analyser.analyse(
            experiment: experiment(), observations: obs);
        expect(result.conclusion.isNotEmpty, isTrue);
      }
    });
  });
}
