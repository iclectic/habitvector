import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/application/adaptive/cold_start_rules.dart';
import 'package:habit_flow/application/adaptive/personalised_scorer.dart';
import 'package:habit_flow/application/adaptive/recommendation_engine.dart';
import 'package:habit_flow/data/database/app_database.dart';
import 'package:habit_flow/data/repositories/drift_habit_repository.dart';
import 'package:habit_flow/data/repositories/drift_recommendation_repository.dart';
import 'package:habit_flow/domain/entities/adaptive_recommendation.dart';
import 'package:habit_flow/domain/entities/habit.dart';
import 'package:habit_flow/domain/entities/habit_log.dart';
import 'package:habit_flow/domain/services/clock.dart';

void main() {
  late AppDatabase db;
  late DriftRecommendationRepository recRepo;
  late RecommendationEngine engine;

  final fixedDate = DateTime(2024, 6, 15);
  final fixedClock = FixedClock(DateTime(2024, 6, 15, 9, 0));

  Habit habit() => Habit(
        id: 'h1',
        title: 'Run',
        colourValue: 0xFF6366F1,
        iconCodePoint: Icons.directions_run.codePoint,
        scheduleType: ScheduleType.daily,
        goalType: GoalType.tick,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  HabitLog completed(DateTime date) => HabitLog(
        id: 'c-${date.millisecondsSinceEpoch}',
        habitId: 'h1',
        date: date,
        completed: true,
        createdAt: date,
      );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    recRepo = DriftRecommendationRepository(db);

    // Seed parent habit row for FK.
    final habitRepo = DriftHabitRepository(db);
    await habitRepo.insertHabit(habit());

    engine = RecommendationEngine(
      repo: recRepo,
      clock: fixedClock,
    );
  });

  tearDown(() async => db.close());

  // ---------------------------------------------------------------------------
  // Cold-start routing
  // ---------------------------------------------------------------------------
  group('RecommendationEngine — cold-start routing', () {
    test('uses cold-start when completed logs < 14', () async {
      final logs = List.generate(
        13,
        (i) => completed(fixedDate.subtract(Duration(days: i + 1))),
      );
      final rec = await engine.recommend(
        habit: habit(),
        recentLogs: logs,
        forDate: fixedDate,
      );
      expect(rec.source, RecommendationSource.coldStartRules);
      expect(rec.modelVersion, kColdStartRulesVersion);
    });

    test('uses cold-start when no logs at all', () async {
      final rec = await engine.recommend(
        habit: habit(),
        recentLogs: [],
        forDate: fixedDate,
      );
      expect(rec.source, RecommendationSource.coldStartRules);
    });
  });

  // ---------------------------------------------------------------------------
  // Personalised routing
  // ---------------------------------------------------------------------------
  group('RecommendationEngine — personalised routing', () {
    test('uses personalised scorer when completed logs >= 14', () async {
      final logs = List.generate(
        14,
        (i) => completed(fixedDate.subtract(Duration(days: i + 1))),
      );
      final rec = await engine.recommend(
        habit: habit(),
        recentLogs: logs,
        forDate: fixedDate,
      );
      expect(rec.source, RecommendationSource.personalisedScoring);
      expect(rec.modelVersion, kPersonalisedScorerVersion);
    });

    test('uses personalised scorer when completed logs > 14', () async {
      final logs = List.generate(
        20,
        (i) => completed(fixedDate.subtract(Duration(days: i + 1))),
      );
      final rec = await engine.recommend(
        habit: habit(),
        recentLogs: logs,
        forDate: fixedDate,
      );
      expect(rec.source, RecommendationSource.personalisedScoring);
    });
  });

  // ---------------------------------------------------------------------------
  // Caching behaviour
  // ---------------------------------------------------------------------------
  group('RecommendationEngine — same-day caching', () {
    test('second recommend() call returns same recommendation', () async {
      final first = await engine.recommend(
        habit: habit(),
        recentLogs: [],
        forDate: fixedDate,
      );
      final second = await engine.recommend(
        habit: habit(),
        recentLogs: [],
        forDate: fixedDate,
      );
      expect(second.id, first.id);
    });

    test('different date generates new recommendation', () async {
      final day1 = await engine.recommend(
        habit: habit(),
        recentLogs: [],
        forDate: fixedDate,
      );
      final day2 = await engine.recommend(
        habit: habit(),
        recentLogs: [],
        forDate: fixedDate.add(const Duration(days: 1)),
      );
      expect(day2.id, isNot(day1.id));
    });
  });

  // ---------------------------------------------------------------------------
  // Feedback recording
  // ---------------------------------------------------------------------------
  group('RecommendationEngine — feedback', () {
    test('recordFeedback stores feedback and timestamp', () async {
      final rec = await engine.recommend(
        habit: habit(),
        recentLogs: [],
        forDate: fixedDate,
      );
      await engine.recordFeedback(
        recommendationId: rec.id,
        feedback: RecommendationFeedback.accepted,
      );
      final updated = await recRepo.getRecommendationById(rec.id);
      expect(updated!.feedback, RecommendationFeedback.accepted);
      expect(updated.feedbackAt, isNotNull);
    });

    test('recordFeedback with note stores note', () async {
      final rec = await engine.recommend(
        habit: habit(),
        recentLogs: [],
        forDate: fixedDate,
      );
      await engine.recordFeedback(
        recommendationId: rec.id,
        feedback: RecommendationFeedback.rejected,
        note: 'Not relevant today',
      );
      final updated = await recRepo.getRecommendationById(rec.id);
      expect(updated!.feedbackNote, 'Not relevant today');
    });

    test('recordFeedback for unknown id is a no-op', () async {
      await expectLater(
        engine.recordFeedback(
          recommendationId: 'nonexistent',
          feedback: RecommendationFeedback.accepted,
        ),
        completes,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Outcome recording
  // ---------------------------------------------------------------------------
  group('RecommendationEngine — outcome recording', () {
    test('recordOutcome marks recommendation as completed', () async {
      final rec = await engine.recommend(
        habit: habit(),
        recentLogs: [],
        forDate: fixedDate,
      );
      await engine.recordOutcome(habitId: 'h1', completed: true);
      final updated = await recRepo.getRecommendationById(rec.id);
      expect(updated!.completed, isTrue);
      expect(updated.completedAt, isNotNull);
    });

    test('recordOutcome for non-today recommendation is a no-op', () async {
      // Create a recommendation for yesterday.
      final yesterday = fixedDate.subtract(const Duration(days: 1));
      final rec = await engine.recommend(
        habit: habit(),
        recentLogs: [],
        forDate: yesterday,
      );
      // Clock is fixed at fixedDate, so yesterday's rec is "not today".
      await engine.recordOutcome(habitId: 'h1', completed: true);
      final unchanged = await recRepo.getRecommendationById(rec.id);
      expect(unchanged!.completed, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // computeRecoveryMetrics
  // ---------------------------------------------------------------------------
  group('RecommendationEngine — computeRecoveryMetrics', () {
    test('returns empty metrics with no logs', () {
      final m = engine.computeRecoveryMetrics(
        habit: habit(),
        logs: [],
      );
      expect(m.habitId, 'h1');
      expect(m.observationCount, 0);
      expect(m.isSufficient, isFalse);
    });

    test('returns metrics with data', () {
      final logs = List.generate(
        10,
        (i) => completed(fixedDate.subtract(Duration(days: i + 1))),
      );
      final m = engine.computeRecoveryMetrics(
        habit: habit(),
        logs: logs,
        asOf: fixedDate,
      );
      expect(m.habitId, 'h1');
    });
  });
}
