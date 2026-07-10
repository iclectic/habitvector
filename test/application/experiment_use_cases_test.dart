import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/application/experiments/experiment_use_cases.dart';
import 'package:habit_flow/data/database/app_database.dart';
import 'package:habit_flow/data/repositories/drift_experiment_repository.dart';
import 'package:habit_flow/data/repositories/drift_habit_repository.dart';
import 'package:habit_flow/domain/entities/habit.dart';
import 'package:habit_flow/domain/entities/habit_experiment.dart';
import 'package:habit_flow/domain/services/clock.dart';

void main() {
  late AppDatabase db;
  late ExperimentUseCases useCases;

  final fixedNow = DateTime(2024, 6, 15, 9, 0);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());

    // Seed parent habit row (FK).
    final habitRepo = DriftHabitRepository(db);
    await habitRepo.insertHabit(Habit(
      id: 'h1',
      title: 'Run',
      colourValue: 0xFF6366F1,
      iconCodePoint: Icons.directions_run.codePoint,
      scheduleType: ScheduleType.daily,
      goalType: GoalType.tick,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    ));

    useCases = ExperimentUseCases(
      repo: DriftExperimentRepository(db),
      clock: FixedClock(fixedNow),
    );
  });

  tearDown(() async => db.close());

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------
  group('ExperimentUseCases — createExperiment', () {
    test('creates experiment in draft state', () async {
      final exp = await useCases.createExperiment(
        habitId: 'h1',
        title: 'Morning vs Evening',
        hypothesis: 'Morning is better',
        primaryOutcome: 'completion rate',
        interventionA: 'Morning',
        interventionB: 'Evening',
        assignmentStrategy: AssignmentStrategy.alternating,
        durationDays: 21,
        minimumObservations: 10,
      );
      expect(exp.status, ExperimentStatus.draft);
      expect(exp.habitId, 'h1');
      expect(exp.durationDays, 21);
    });

    test('throws when durationDays < 1', () async {
      await expectLater(
        () => useCases.createExperiment(
          habitId: 'h1',
          title: 'X',
          hypothesis: 'X',
          primaryOutcome: 'X',
          interventionA: 'A',
          interventionB: 'B',
          assignmentStrategy: AssignmentStrategy.alternating,
          durationDays: 0,
          minimumObservations: 10,
        ),
        throwsArgumentError,
      );
    });

    test('throws when minimumObservations < 2', () async {
      await expectLater(
        () => useCases.createExperiment(
          habitId: 'h1',
          title: 'X',
          hypothesis: 'X',
          primaryOutcome: 'X',
          interventionA: 'A',
          interventionB: 'B',
          assignmentStrategy: AssignmentStrategy.alternating,
          durationDays: 10,
          minimumObservations: 1,
        ),
        throwsArgumentError,
      );
    });

    test('throws when habit already has an active experiment', () async {
      final exp = await _createDefault(useCases);
      await useCases.startExperiment(exp.id);

      await expectLater(
        () => useCases.createExperiment(
          habitId: 'h1',
          title: 'Another',
          hypothesis: 'X',
          primaryOutcome: 'X',
          interventionA: 'A',
          interventionB: 'B',
          assignmentStrategy: AssignmentStrategy.alternating,
          durationDays: 10,
          minimumObservations: 4,
        ),
        throwsStateError,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  group('ExperimentUseCases — lifecycle', () {
    test('draft → active via startExperiment', () async {
      final exp = await _createDefault(useCases);
      final started = await useCases.startExperiment(exp.id);
      expect(started.status, ExperimentStatus.active);
    });

    test('active → paused via pauseExperiment', () async {
      final exp = await _createDefault(useCases);
      await useCases.startExperiment(exp.id);
      final paused = await useCases.pauseExperiment(exp.id);
      expect(paused.status, ExperimentStatus.paused);
    });

    test('paused → active via resumeExperiment', () async {
      final exp = await _createDefault(useCases);
      await useCases.startExperiment(exp.id);
      await useCases.pauseExperiment(exp.id);
      final resumed = await useCases.resumeExperiment(exp.id);
      expect(resumed.status, ExperimentStatus.active);
    });

    test('active → completed via completeExperiment', () async {
      final exp = await _createDefault(useCases);
      await useCases.startExperiment(exp.id);
      final completed = await useCases.completeExperiment(exp.id);
      expect(completed.status, ExperimentStatus.completed);
      expect(completed.endDate, isNotNull);
    });

    test('completed experiment has non-null resultSummary', () async {
      final exp = await _createDefault(useCases);
      await useCases.startExperiment(exp.id);
      final completed = await useCases.completeExperiment(exp.id);
      expect(completed.resultSummary, isNotNull);
      expect(completed.resultSummary!.isNotEmpty, isTrue);
    });

    test('active → cancelled via cancelExperiment', () async {
      final exp = await _createDefault(useCases);
      await useCases.startExperiment(exp.id);
      final cancelled = await useCases.cancelExperiment(exp.id);
      expect(cancelled.status, ExperimentStatus.cancelled);
    });

    test('cannot start a non-draft experiment', () async {
      final exp = await _createDefault(useCases);
      await useCases.startExperiment(exp.id);
      await expectLater(
        () => useCases.startExperiment(exp.id),
        throwsStateError,
      );
    });

    test('cannot cancel a completed experiment', () async {
      final exp = await _createDefault(useCases);
      await useCases.startExperiment(exp.id);
      await useCases.completeExperiment(exp.id);
      await expectLater(
        () => useCases.cancelExperiment(exp.id),
        throwsStateError,
      );
    });

    test('throws for unknown experiment id', () async {
      await expectLater(
        () => useCases.startExperiment('nonexistent'),
        throwsStateError,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Observations
  // ---------------------------------------------------------------------------
  group('ExperimentUseCases — observations', () {
    test('records observation with auto-assigned arm', () async {
      final exp = await _createDefault(useCases);
      await useCases.startExperiment(exp.id);
      final obs = await useCases.recordObservation(
        experimentId: exp.id,
        completed: true,
      );
      expect(obs.experimentId, exp.id);
      expect(obs.assignment,
          anyOf(InterventionAssignment.a, InterventionAssignment.b));
    });

    test('alternating: first obs = A, second = B', () async {
      final exp = await _createDefault(useCases,
          strategy: AssignmentStrategy.alternating);
      await useCases.startExperiment(exp.id);

      final obs1 = await useCases.recordObservation(
        experimentId: exp.id,
        completed: true,
        date: DateTime(2024, 6, 15),
      );
      final obs2 = await useCases.recordObservation(
        experimentId: exp.id,
        completed: false,
        date: DateTime(2024, 6, 16),
      );
      expect(obs1.assignment, InterventionAssignment.a);
      expect(obs2.assignment, InterventionAssignment.b);
    });

    test('throws when recording on paused experiment', () async {
      final exp = await _createDefault(useCases);
      await useCases.startExperiment(exp.id);
      await useCases.pauseExperiment(exp.id);
      await expectLater(
        () => useCases.recordObservation(
          experimentId: exp.id,
          completed: true,
        ),
        throwsStateError,
      );
    });

    test('throws on duplicate observation for the same date', () async {
      final exp = await _createDefault(useCases);
      await useCases.startExperiment(exp.id);
      await useCases.recordObservation(
        experimentId: exp.id,
        completed: true,
        date: DateTime(2024, 6, 15),
      );
      await expectLater(
        () => useCases.recordObservation(
          experimentId: exp.id,
          completed: false,
          date: DateTime(2024, 6, 15),
        ),
        throwsStateError,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Analysis
  // ---------------------------------------------------------------------------
  group('ExperimentUseCases — getAnalysis', () {
    test('returns analysis without error even with no observations', () async {
      final exp = await _createDefault(useCases);
      await useCases.startExperiment(exp.id);
      final analysis = await useCases.getAnalysis(exp.id);
      expect(analysis, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // peekNextAssignment
  // ---------------------------------------------------------------------------
  group('ExperimentUseCases — peekNextAssignment', () {
    test('returns next arm without recording', () async {
      final exp = await _createDefault(useCases,
          strategy: AssignmentStrategy.alternating);
      await useCases.startExperiment(exp.id);
      final next = await useCases.peekNextAssignment(exp.id);
      expect(next, InterventionAssignment.a); // first observation, index 0

      // After recording, peek should show B.
      await useCases.recordObservation(
        experimentId: exp.id,
        completed: true,
        date: DateTime(2024, 6, 15),
      );
      final next2 = await useCases.peekNextAssignment(exp.id);
      expect(next2, InterventionAssignment.b);
    });
  });

  // ---------------------------------------------------------------------------
  // confoundingNotes
  // ---------------------------------------------------------------------------
  group('ExperimentUseCases — confoundingNotes', () {
    test('adds confounding note to experiment', () async {
      final exp = await _createDefault(useCases);
      await useCases.startExperiment(exp.id);
      final updated =
          await useCases.addConfoundingNote(exp.id, 'Started new job');
      expect(updated.confoundingNotes, 'Started new job');
    });
  });
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Future<HabitExperiment> _createDefault(
  ExperimentUseCases useCases, {
  AssignmentStrategy strategy = AssignmentStrategy.alternating,
}) =>
    useCases.createExperiment(
      habitId: 'h1',
      title: 'Morning vs Evening',
      hypothesis: 'Morning is better',
      primaryOutcome: 'completion rate',
      interventionA: 'Morning',
      interventionB: 'Evening',
      assignmentStrategy: strategy,
      durationDays: 21,
      minimumObservations: 10,
    );
