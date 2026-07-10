import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/data/database/app_database.dart';
import 'package:habit_flow/data/repositories/drift_context_repository.dart';
import 'package:habit_flow/data/repositories/drift_shift_repository.dart';
import 'package:habit_flow/data/repositories/drift_habit_versions_repository.dart';
import 'package:habit_flow/data/repositories/drift_recommendation_repository.dart';
import 'package:habit_flow/data/repositories/drift_experiment_repository.dart';
import 'package:habit_flow/data/repositories/drift_habit_repository.dart';
import 'package:habit_flow/domain/entities/daily_check_in.dart';
import 'package:habit_flow/domain/entities/habit.dart';
import 'package:habit_flow/domain/entities/habit_experiment.dart';
import 'package:habit_flow/domain/entities/habit_versions.dart';
import 'package:habit_flow/domain/entities/work_shift.dart';
import 'package:habit_flow/domain/entities/adaptive_recommendation.dart';

void main() {
  late AppDatabase db;
  late DriftHabitRepository habitRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    habitRepo = DriftHabitRepository(db);

    // Seed a parent habit for FK references.
    final now = DateTime(2024, 6, 1);
    await habitRepo.insertHabit(Habit(
      id: 'h1',
      title: 'Test Habit',
      colourValue: 0xFF6366F1,
      iconCodePoint: Icons.fitness_center.codePoint,
      scheduleType: ScheduleType.daily,
      goalType: GoalType.tick,
      createdAt: now,
      updatedAt: now,
    ));
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // DailyCheckIn
  // ---------------------------------------------------------------------------
  group('DriftContextRepository', () {
    late DriftContextRepository repo;

    setUp(() {
      repo = DriftContextRepository(db);
    });

    test('insert and retrieve check-in for date', () async {
      final checkIn = DailyCheckIn(
        id: 'ci1',
        date: DateTime(2024, 6, 10),
        energyLevel: EnergyLevel.high,
        workloadLevel: WorkloadLevel.moderate,
        dayType: DayType.restDay,
        createdAt: DateTime(2024, 6, 10, 8),
      );
      await repo.insertCheckIn(checkIn);

      final retrieved =
          await repo.getCheckInForDate(DateTime(2024, 6, 10));
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'ci1');
      expect(retrieved.energyLevel, EnergyLevel.high);
      expect(retrieved.workloadLevel, WorkloadLevel.moderate);
      expect(retrieved.dayType, DayType.restDay);
    });

    test('returns null for date with no check-in', () async {
      final result = await repo.getCheckInForDate(DateTime(2024, 1, 1));
      expect(result, isNull);
    });

    test('update check-in', () async {
      final checkIn = DailyCheckIn(
        id: 'ci1',
        date: DateTime(2024, 6, 10),
        createdAt: DateTime(2024, 6, 10),
      );
      await repo.insertCheckIn(checkIn);

      final updated = checkIn.copyWith(energyLevel: EnergyLevel.veryHigh);
      await repo.updateCheckIn(updated);

      final retrieved =
          await repo.getCheckInForDate(DateTime(2024, 6, 10));
      expect(retrieved!.energyLevel, EnergyLevel.veryHigh);
    });

    test('delete check-in', () async {
      final checkIn = DailyCheckIn(
        id: 'ci1',
        date: DateTime(2024, 6, 10),
        createdAt: DateTime(2024, 6, 10),
      );
      await repo.insertCheckIn(checkIn);
      await repo.deleteCheckIn('ci1');

      final result =
          await repo.getCheckInForDate(DateTime(2024, 6, 10));
      expect(result, isNull);
    });

    test('get check-ins in range', () async {
      for (var i = 1; i <= 5; i++) {
        await repo.insertCheckIn(DailyCheckIn(
          id: 'ci$i',
          date: DateTime(2024, 6, i),
          createdAt: DateTime(2024, 6, i),
        ));
      }

      final results = await repo.getCheckInsInRange(
        DateTime(2024, 6, 2),
        DateTime(2024, 6, 4),
      );
      expect(results.length, 3);
      expect(results.first.id, 'ci2');
      expect(results.last.id, 'ci4');
    });

    test('check-in with all optional fields null', () async {
      final checkIn = DailyCheckIn(
        id: 'ci-empty',
        date: DateTime(2024, 7, 1),
        createdAt: DateTime(2024, 7, 1),
      );
      await repo.insertCheckIn(checkIn);

      final retrieved =
          await repo.getCheckInForDate(DateTime(2024, 7, 1));
      expect(retrieved, isNotNull);
      expect(retrieved!.energyLevel, isNull);
      expect(retrieved.workloadLevel, isNull);
      expect(retrieved.availableMinutes, isNull);
      expect(retrieved.confidenceScore, isNull);
      expect(retrieved.notes, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // WorkShift
  // ---------------------------------------------------------------------------
  group('DriftShiftRepository', () {
    late DriftShiftRepository repo;

    setUp(() {
      repo = DriftShiftRepository(db);
    });

    WorkShift makeShift({
      String id = 'ws1',
      String label = 'Day shift',
      DateTime? start,
      DateTime? end,
    }) {
      final s = start ?? DateTime(2024, 6, 10, 7);
      final e = end ?? DateTime(2024, 6, 10, 15);
      return WorkShift(
        id: id,
        label: label,
        startTime: s,
        endTime: e,
        createdAt: s,
        updatedAt: s,
      );
    }

    test('insert and retrieve shift by id', () async {
      await repo.insertShift(makeShift());
      final result = await repo.getShiftById('ws1');
      expect(result, isNotNull);
      expect(result!.label, 'Day shift');
    });

    test('returns null for missing shift', () async {
      expect(await repo.getShiftById('missing'), isNull);
    });

    test('get shifts for date', () async {
      await repo.insertShift(makeShift(
        id: 'ws1',
        start: DateTime(2024, 6, 10, 7),
        end: DateTime(2024, 6, 10, 15),
      ));
      await repo.insertShift(makeShift(
        id: 'ws2',
        start: DateTime(2024, 6, 11, 7),
        end: DateTime(2024, 6, 11, 15),
      ));

      final results = await repo.getShiftsForDate(DateTime(2024, 6, 10));
      expect(results.length, 1);
      expect(results.first.id, 'ws1');
    });

    test('archive removes from active list', () async {
      await repo.insertShift(makeShift());
      await repo.archiveShift('ws1');

      final active = await repo.getActiveShifts();
      expect(active, isEmpty);
    });

    test('delete shift', () async {
      await repo.insertShift(makeShift());
      await repo.deleteShift('ws1');
      expect(await repo.getShiftById('ws1'), isNull);
    });

    test('overnight shift stored and retrieved correctly', () async {
      final shift = WorkShift(
        id: 'ws-night',
        label: 'Night shift',
        startTime: DateTime(2024, 6, 10, 22),
        endTime: DateTime(2024, 6, 11, 6),
        isOvernight: true,
        recurrence: ShiftRecurrence.weekly,
        recurrenceWeekdays: [1, 3, 5],
        createdAt: DateTime(2024, 6, 10),
        updatedAt: DateTime(2024, 6, 10),
      );
      await repo.insertShift(shift);

      final result = await repo.getShiftById('ws-night');
      expect(result!.isOvernight, isTrue);
      expect(result.recurrence, ShiftRecurrence.weekly);
      expect(result.recurrenceWeekdays, [1, 3, 5]);
    });
  });

  // ---------------------------------------------------------------------------
  // HabitVersions
  // ---------------------------------------------------------------------------
  group('DriftHabitVersionsRepository', () {
    late DriftHabitVersionsRepository repo;

    setUp(() {
      repo = DriftHabitVersionsRepository(db);
    });

    test('upsert and retrieve versions', () async {
      final versions = HabitVersions(
        id: 'hv1',
        habitId: 'h1',
        minimumDescription: '5-min walk',
        minimumDurationMinutes: 5,
        standardDescription: '20-min walk',
        standardDurationMinutes: 20,
        stretchDescription: '40-min walk',
        stretchDurationMinutes: 40,
        createdAt: DateTime(2024, 6, 1),
        updatedAt: DateTime(2024, 6, 1),
      );
      await repo.upsertVersions(versions);

      final result = await repo.getVersionsForHabit('h1');
      expect(result, isNotNull);
      expect(result!.minimumDescription, '5-min walk');
      expect(result.minimumDurationMinutes, 5);
      expect(result.stretchDurationMinutes, 40);
    });

    test('returns null for habit with no versions', () async {
      final result = await repo.getVersionsForHabit('no-such-habit-id');
      expect(result, isNull);
    });

    test('upsert updates existing versions', () async {
      final versions = HabitVersions(
        id: 'hv1',
        habitId: 'h1',
        minimumDescription: '5-min walk',
        minimumDurationMinutes: 5,
        createdAt: DateTime(2024, 6, 1),
        updatedAt: DateTime(2024, 6, 1),
      );
      await repo.upsertVersions(versions);

      final updated = versions.copyWith(minimumDurationMinutes: 10);
      await repo.upsertVersions(updated);

      final result = await repo.getVersionsForHabit('h1');
      expect(result!.minimumDurationMinutes, 10);
    });

    test('delete versions for habit', () async {
      final versions = HabitVersions(
        id: 'hv1',
        habitId: 'h1',
        createdAt: DateTime(2024, 6, 1),
        updatedAt: DateTime(2024, 6, 1),
      );
      await repo.upsertVersions(versions);
      await repo.deleteVersionsForHabit('h1');

      expect(await repo.getVersionsForHabit('h1'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AdaptiveRecommendation
  // ---------------------------------------------------------------------------
  group('DriftRecommendationRepository', () {
    late DriftRecommendationRepository repo;

    setUp(() {
      repo = DriftRecommendationRepository(db);
    });

    AdaptiveRecommendation makeRec({
      String id = 'r1',
      DateTime? forDate,
    }) {
      return AdaptiveRecommendation(
        id: id,
        habitId: 'h1',
        generatedAt: DateTime(2024, 6, 10, 8),
        forDate: forDate ?? DateTime(2024, 6, 10),
        action: RecommendedAction.completeStandard,
        confidence: 0.65,
        explanation: 'You completed this on 4 of the last 5 rest days.',
        factorsUsed: ['rest_day', 'high_energy'],
        factorsMissing: ['shift_label'],
        alternativeAction: RecommendedAction.useMinimumVersion,
        modelVersion: 'cold-start-v1',
        source: RecommendationSource.coldStartRules,
      );
    }

    test('insert and retrieve recommendation', () async {
      await repo.insertRecommendation(makeRec());
      final result = await repo.getRecommendationById('r1');
      expect(result, isNotNull);
      expect(result!.action, RecommendedAction.completeStandard);
      expect(result.confidence, closeTo(0.65, 0.001));
      expect(result.factorsUsed, ['rest_day', 'high_energy']);
      expect(result.factorsMissing, ['shift_label']);
    });

    test('returns null for missing recommendation', () async {
      expect(await repo.getRecommendationById('nope'), isNull);
    });

    test('get latest for habit returns the most recently generated one',
        () async {
      final older = AdaptiveRecommendation(
        id: 'r1',
        habitId: 'h1',
        generatedAt: DateTime(2024, 6, 9, 8),
        forDate: DateTime(2024, 6, 9),
        action: RecommendedAction.completeStandard,
        confidence: 0.65,
        explanation: 'Older recommendation.',
        factorsUsed: [],
        factorsMissing: [],
        alternativeAction: RecommendedAction.useMinimumVersion,
        modelVersion: 'cold-start-v1',
        source: RecommendationSource.coldStartRules,
      );
      final newer = AdaptiveRecommendation(
        id: 'r2',
        habitId: 'h1',
        generatedAt: DateTime(2024, 6, 10, 8),
        forDate: DateTime(2024, 6, 10),
        action: RecommendedAction.useMinimumVersion,
        confidence: 0.7,
        explanation: 'Newer recommendation.',
        factorsUsed: [],
        factorsMissing: [],
        alternativeAction: RecommendedAction.leavePlanUnchanged,
        modelVersion: 'cold-start-v1',
        source: RecommendationSource.coldStartRules,
      );
      await repo.insertRecommendation(older);
      await repo.insertRecommendation(newer);

      final latest = await repo.getLatestRecommendationForHabit('h1');
      expect(latest!.id, 'r2');
    });

    test('update recommendation with feedback', () async {
      final rec = makeRec();
      await repo.insertRecommendation(rec);

      final withFeedback = rec.copyWith(
        feedback: RecommendationFeedback.accepted,
        feedbackAt: DateTime(2024, 6, 10, 9),
      );
      await repo.updateRecommendation(withFeedback);

      final result = await repo.getRecommendationById('r1');
      expect(result!.feedback, RecommendationFeedback.accepted);
    });

    test('delete recommendation', () async {
      await repo.insertRecommendation(makeRec());
      await repo.deleteRecommendation('r1');
      expect(await repo.getRecommendationById('r1'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // HabitExperiment + ExperimentObservation
  // ---------------------------------------------------------------------------
  group('DriftExperimentRepository', () {
    late DriftExperimentRepository repo;

    setUp(() {
      repo = DriftExperimentRepository(db);
    });

    HabitExperiment makeExperiment({String id = 'exp1'}) {
      final now = DateTime(2024, 6, 1);
      return HabitExperiment(
        id: id,
        habitId: 'h1',
        title: 'Morning vs Evening',
        hypothesis: 'Morning timing increases completion rate',
        primaryOutcome: 'completion rate',
        interventionA: 'Reminder at 07:00',
        interventionB: 'Reminder at 19:00',
        assignmentStrategy: AssignmentStrategy.alternating,
        durationDays: 21,
        minimumObservations: 10,
        startDate: now,
        status: ExperimentStatus.active,
        createdAt: now,
        updatedAt: now,
      );
    }

    ExperimentObservation makeObservation({
      String id = 'obs1',
      String experimentId = 'exp1',
      DateTime? date,
      InterventionAssignment assignment = InterventionAssignment.a,
      bool completed = true,
    }) {
      return ExperimentObservation(
        id: id,
        experimentId: experimentId,
        habitId: 'h1',
        date: date ?? DateTime(2024, 6, 1),
        assignment: assignment,
        completed: completed,
        createdAt: DateTime(2024, 6, 1),
      );
    }

    test('insert and retrieve experiment', () async {
      await repo.insertExperiment(makeExperiment());
      final result = await repo.getExperimentById('exp1');
      expect(result, isNotNull);
      expect(result!.title, 'Morning vs Evening');
      expect(result.status, ExperimentStatus.active);
      expect(result.assignmentStrategy, AssignmentStrategy.alternating);
    });

    test('returns null for missing experiment', () async {
      expect(await repo.getExperimentById('nope'), isNull);
    });

    test('update experiment status to completed', () async {
      final exp = makeExperiment();
      await repo.insertExperiment(exp);

      final completed =
          exp.copyWith(status: ExperimentStatus.completed);
      await repo.updateExperiment(completed);

      final result = await repo.getExperimentById('exp1');
      expect(result!.status, ExperimentStatus.completed);
    });

    test('insert and retrieve observations', () async {
      await repo.insertExperiment(makeExperiment());

      await repo.insertObservation(makeObservation(
        id: 'obs1',
        assignment: InterventionAssignment.a,
        completed: true,
        date: DateTime(2024, 6, 1),
      ));
      await repo.insertObservation(makeObservation(
        id: 'obs2',
        assignment: InterventionAssignment.b,
        completed: false,
        date: DateTime(2024, 6, 2),
      ));

      final observations =
          await repo.getObservationsForExperiment('exp1');
      expect(observations.length, 2);
      expect(observations.first.assignment, InterventionAssignment.a);
      expect(observations.last.assignment, InterventionAssignment.b);
      expect(observations.last.completed, isFalse);
    });

    test('get observation for specific date', () async {
      await repo.insertExperiment(makeExperiment());
      await repo.insertObservation(makeObservation(
        date: DateTime(2024, 6, 5),
      ));

      final obs = await repo.getObservationForDate(
          'exp1', DateTime(2024, 6, 5));
      expect(obs, isNotNull);
      expect(obs!.id, 'obs1');
    });

    test('returns null observation for date with no entry', () async {
      await repo.insertExperiment(makeExperiment());
      final obs = await repo.getObservationForDate(
          'exp1', DateTime(2024, 1, 1));
      expect(obs, isNull);
    });

    test('delete observations for experiment', () async {
      await repo.insertExperiment(makeExperiment());
      for (var i = 1; i <= 3; i++) {
        await repo.insertObservation(makeObservation(
          id: 'obs$i',
          date: DateTime(2024, 6, i),
        ));
      }

      await repo.deleteObservationsForExperiment('exp1');
      final remaining =
          await repo.getObservationsForExperiment('exp1');
      expect(remaining, isEmpty);
    });

    test('get active experiments only', () async {
      await repo.insertExperiment(makeExperiment(id: 'exp1'));

      final now = DateTime(2024, 6, 1);
      await repo.insertExperiment(HabitExperiment(
        id: 'exp2',
        habitId: 'h1',
        title: 'Cancelled',
        hypothesis: 'h',
        primaryOutcome: 'completion',
        interventionA: 'A',
        interventionB: 'B',
        assignmentStrategy: AssignmentStrategy.randomised,
        durationDays: 14,
        minimumObservations: 5,
        startDate: now,
        status: ExperimentStatus.cancelled,
        createdAt: now,
        updatedAt: now,
      ));

      final active = await repo.getActiveExperiments();
      expect(active.length, 1);
      expect(active.first.id, 'exp1');
    });
  });
}
