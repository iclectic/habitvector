import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/application/experiments/assignment_engine.dart';
import 'package:habit_flow/domain/entities/habit_experiment.dart';

void main() {
  const engine = AssignmentEngine();

  HabitExperiment experiment({
    String id = 'exp1',
    AssignmentStrategy strategy = AssignmentStrategy.alternating,
  }) =>
      HabitExperiment(
        id: id,
        habitId: 'h1',
        title: 'Test',
        hypothesis: 'Morning vs evening is better',
        primaryOutcome: 'completion rate',
        interventionA: 'Morning',
        interventionB: 'Evening',
        assignmentStrategy: strategy,
        durationDays: 30,
        minimumObservations: 10,
        startDate: DateTime(2024, 6, 1),
        status: ExperimentStatus.active,
        createdAt: DateTime(2024, 6, 1),
        updatedAt: DateTime(2024, 6, 1),
      );

  // ---------------------------------------------------------------------------
  // Alternating strategy
  // ---------------------------------------------------------------------------
  group('AssignmentEngine — alternating', () {
    final exp = experiment(strategy: AssignmentStrategy.alternating);

    test('index 0 → A', () {
      expect(engine.assign(experiment: exp, existingCount: 0),
          InterventionAssignment.a);
    });

    test('index 1 → B', () {
      expect(engine.assign(experiment: exp, existingCount: 1),
          InterventionAssignment.b);
    });

    test('index 2 → A', () {
      expect(engine.assign(experiment: exp, existingCount: 2),
          InterventionAssignment.a);
    });

    test('index 9 → B (odd)', () {
      expect(engine.assign(experiment: exp, existingCount: 9),
          InterventionAssignment.b);
    });

    test('alternating sequence is strictly A-B-A-B', () {
      final seq = engine.previewSequence(
          experiment: exp, totalObservations: 10);
      for (int i = 0; i < seq.length; i++) {
        final expected =
            i.isEven ? InterventionAssignment.a : InterventionAssignment.b;
        expect(seq[i], expected, reason: 'Index $i should be $expected');
      }
    });

    test('10-observation alternating sequence is perfectly balanced', () {
      expect(
          engine.isBalanced(experiment: exp, totalObservations: 10), isTrue);
    });

    test('11-observation alternating sequence is balanced within ±1', () {
      expect(
          engine.isBalanced(experiment: exp, totalObservations: 11), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Randomised strategy
  // ---------------------------------------------------------------------------
  group('AssignmentEngine — randomised', () {
    final exp =
        experiment(strategy: AssignmentStrategy.randomised, id: 'exp-rand');

    test('same experiment + same index always gives same assignment', () {
      final first = engine.assign(experiment: exp, existingCount: 5);
      final second = engine.assign(experiment: exp, existingCount: 5);
      expect(first, second);
    });

    test('different index can give different assignment', () {
      // With a sufficiently long sequence, both arms should appear.
      final seq = engine.previewSequence(
          experiment: exp, totalObservations: 20);
      final aCount =
          seq.where((s) => s == InterventionAssignment.a).length;
      final bCount =
          seq.where((s) => s == InterventionAssignment.b).length;
      expect(aCount, greaterThan(0));
      expect(bCount, greaterThan(0));
    });

    test('different experiment ids produce independent sequences', () {
      final expA = experiment(
          id: 'alpha', strategy: AssignmentStrategy.randomised);
      final expB = experiment(
          id: 'beta', strategy: AssignmentStrategy.randomised);

      final seqA = engine.previewSequence(
          experiment: expA, totalObservations: 20);
      final seqB = engine.previewSequence(
          experiment: expB, totalObservations: 20);

      // Not all elements should be identical (independence).
      final allSame =
          List.generate(20, (i) => seqA[i] == seqB[i]).every((x) => x);
      expect(allSame, isFalse,
          reason: 'Different experiment IDs should produce different sequences');
    });

    test('randomised sequence over 50 observations has both arms present', () {
      final seq =
          engine.previewSequence(experiment: exp, totalObservations: 50);
      final aCount =
          seq.where((s) => s == InterventionAssignment.a).length;
      final bCount =
          seq.where((s) => s == InterventionAssignment.b).length;
      // Both arms must appear at least once in 50 observations.
      expect(aCount, greaterThan(0));
      expect(bCount, greaterThan(0));
    });
  });

  // ---------------------------------------------------------------------------
  // previewSequence
  // ---------------------------------------------------------------------------
  group('AssignmentEngine — previewSequence', () {
    test('length matches totalObservations', () {
      final exp = experiment();
      final seq = engine.previewSequence(
          experiment: exp, totalObservations: 7);
      expect(seq.length, 7);
    });

    test('empty sequence for 0 observations', () {
      final exp = experiment();
      final seq = engine.previewSequence(
          experiment: exp, totalObservations: 0);
      expect(seq, isEmpty);
    });
  });
}
