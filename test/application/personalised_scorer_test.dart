import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/application/adaptive/context_feature_builder.dart';
import 'package:habit_flow/application/adaptive/personalised_scorer.dart';
import 'package:habit_flow/domain/entities/adaptive_recommendation.dart';
import 'package:habit_flow/domain/entities/daily_check_in.dart';
import 'package:habit_flow/domain/entities/habit.dart';
import 'package:habit_flow/domain/entities/habit_log.dart';
import 'package:habit_flow/domain/entities/habit_versions.dart';
import 'package:habit_flow/domain/entities/recovery_metrics.dart';

void main() {
  const scorer = PersonalisedScorer();
  final today = DateTime(2024, 6, 15);

  Habit dailyHabit() => Habit(
        id: 'h1',
        title: 'Run',
        colourValue: 0xFF6366F1,
        iconCodePoint: 0xe3c9,
        scheduleType: ScheduleType.daily,
        goalType: GoalType.tick,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  HabitLog completedLog(DateTime date) => HabitLog(
        id: 'c-${date.toIso8601String()}',
        habitId: 'h1',
        date: date,
        completed: true,
        createdAt: date,
      );

  HabitLog missedLog(DateTime date) => HabitLog(
        id: 'm-${date.toIso8601String()}',
        habitId: 'h1',
        date: date,
        completed: false,
        createdAt: date,
      );

  DailyCheckIn checkIn({
    EnergyLevel? energyLevel,
    WorkloadLevel? workloadLevel,
    DayType? dayType,
    int? availableMinutes,
  }) =>
      DailyCheckIn(
        id: 'ci1',
        date: today,
        energyLevel: energyLevel,
        workloadLevel: workloadLevel,
        dayType: dayType,
        availableMinutes: availableMinutes,
        createdAt: today,
      );

  ContextFeatures features({
    DailyCheckIn? ci,
    List<HabitLog>? logs,
    Habit? habit,
  }) =>
      ContextFeatures(
        habit: habit ?? dailyHabit(),
        today: today,
        recentLogs: logs ?? [],
        checkIn: ci,
      );

  RecoveryMetrics goodRecovery() => const RecoveryMetrics(
        habitId: 'h1',
        successfulRecoveries: 5,
        lapsedAfterMiss: 1,
        observationCount: 6,
        isSufficient: true,
      );

  RecoveryMetrics poorRecovery() => const RecoveryMetrics(
        habitId: 'h1',
        successfulRecoveries: 1,
        lapsedAfterMiss: 5,
        observationCount: 6,
        isSufficient: true,
      );

  // ---------------------------------------------------------------------------
  // Score → Action routing
  // ---------------------------------------------------------------------------
  group('PersonalisedScorer — action mapping', () {
    test('high energy + light workload + good history → stretch', () {
      final logs = List.generate(
        7,
        (i) => completedLog(today.subtract(Duration(days: i + 1))),
      );
      final result = scorer.evaluate(
        features(
          ci: checkIn(
            energyLevel: EnergyLevel.veryHigh,
            workloadLevel: WorkloadLevel.light,
            dayType: DayType.restDay,
            availableMinutes: 60,
          ),
          logs: logs,
        ),
        recovery: goodRecovery(),
      );
      expect(result.action, RecommendedAction.attemptStretchVersion);
      expect(result.suggestedVersion, HabitVersionLevel.stretch);
    });

    test('moderate energy + moderate workload + decent history → standard', () {
      final logs = List.generate(
        4,
        (i) => completedLog(today.subtract(Duration(days: i + 1))),
      );
      final result = scorer.evaluate(
        features(
          ci: checkIn(
            energyLevel: EnergyLevel.moderate,
            workloadLevel: WorkloadLevel.moderate,
            dayType: DayType.workday,
            availableMinutes: 30,
          ),
          logs: logs,
        ),
      );
      expect(result.action, RecommendedAction.completeStandard);
      expect(result.suggestedVersion, HabitVersionLevel.standard);
    });

    test('low energy + heavy workload + mixed history → minimum or recovery', () {
      final logs = [
        completedLog(today.subtract(const Duration(days: 5))),
        missedLog(today.subtract(const Duration(days: 4))),
        missedLog(today.subtract(const Duration(days: 3))),
        missedLog(today.subtract(const Duration(days: 2))),
        completedLog(today.subtract(const Duration(days: 1))),
      ];
      final result = scorer.evaluate(
        features(
          ci: checkIn(
            energyLevel: EnergyLevel.low,
            workloadLevel: WorkloadLevel.heavy,
            availableMinutes: 10,
          ),
          logs: logs,
        ),
        recovery: poorRecovery(),
      );
      // With low energy (0.25), heavy workload (0.25), and poor recovery,
      // the weighted score is low. Both minimum and recovery-day are valid
      // outcomes depending on the exact score. Either signals reduced capacity.
      expect(
        [
          RecommendedAction.useMinimumVersion,
          RecommendedAction.scheduleRecoveryDay,
        ],
        contains(result.action),
      );
    });

    test('very low energy + overwhelming workload → recovery day', () {
      final result = scorer.evaluate(
        features(
          ci: checkIn(
            energyLevel: EnergyLevel.veryLow,
            workloadLevel: WorkloadLevel.overwhelming,
            availableMinutes: 5,
          ),
        ),
        recovery: poorRecovery(),
      );
      expect(result.action, RecommendedAction.scheduleRecoveryDay);
    });

    test('3 consecutive misses always → recovery day regardless of score', () {
      final logs = [
        completedLog(today.subtract(const Duration(days: 4))),
        missedLog(today.subtract(const Duration(days: 3))),
        missedLog(today.subtract(const Duration(days: 2))),
        missedLog(today.subtract(const Duration(days: 1))),
      ];
      // Even with high energy, the override should kick in.
      final result = scorer.evaluate(
        features(
          ci: checkIn(
            energyLevel: EnergyLevel.veryHigh,
            workloadLevel: WorkloadLevel.light,
          ),
          logs: logs,
        ),
        recovery: goodRecovery(),
      );
      expect(result.action, RecommendedAction.scheduleRecoveryDay);
    });
  });

  // ---------------------------------------------------------------------------
  // Confidence
  // ---------------------------------------------------------------------------
  group('PersonalisedScorer — confidence bounds', () {
    test('confidence is always between 0.45 and 0.90', () {
      final scenarios = [
        features(),
        features(
          ci: checkIn(
            energyLevel: EnergyLevel.veryHigh,
            workloadLevel: WorkloadLevel.light,
            dayType: DayType.restDay,
            availableMinutes: 60,
          ),
          logs: List.generate(
              7, (i) => completedLog(today.subtract(Duration(days: i + 1)))),
        ),
        features(
          ci: checkIn(
            energyLevel: EnergyLevel.veryLow,
            workloadLevel: WorkloadLevel.overwhelming,
            availableMinutes: 0,
          ),
        ),
      ];

      for (final f in scenarios) {
        final result = scorer.evaluate(f);
        expect(result.confidence, greaterThanOrEqualTo(0.45));
        expect(result.confidence, lessThanOrEqualTo(0.90));
      }
    });

    test('richer context increases confidence', () {
      final sparse = scorer.evaluate(features());
      final rich = scorer.evaluate(
        features(
          ci: checkIn(
            energyLevel: EnergyLevel.high,
            workloadLevel: WorkloadLevel.light,
            dayType: DayType.workday,
            availableMinutes: 45,
          ),
          logs: List.generate(
              7, (i) => completedLog(today.subtract(Duration(days: i + 1)))),
        ),
        recovery: goodRecovery(),
      );
      expect(rich.confidence, greaterThanOrEqualTo(sparse.confidence));
    });
  });

  // ---------------------------------------------------------------------------
  // Alternative actions
  // ---------------------------------------------------------------------------
  group('PersonalisedScorer — alternative actions', () {
    test('stretch alternative is standard', () {
      final logs = List.generate(
        7,
        (i) => completedLog(today.subtract(Duration(days: i + 1))),
      );
      final result = scorer.evaluate(
        features(
          ci: checkIn(
            energyLevel: EnergyLevel.veryHigh,
            workloadLevel: WorkloadLevel.light,
            dayType: DayType.restDay,
            availableMinutes: 60,
          ),
          logs: logs,
        ),
        recovery: goodRecovery(),
      );
      if (result.action == RecommendedAction.attemptStretchVersion) {
        expect(result.alternativeAction, RecommendedAction.completeStandard);
      }
    });

    test('minimum version alternative is leavePlanUnchanged', () {
      final result = scorer.evaluate(
        features(
          ci: checkIn(
            energyLevel: EnergyLevel.veryLow,
            workloadLevel: WorkloadLevel.heavy,
            availableMinutes: 5,
          ),
        ),
        recovery: poorRecovery(),
      );
      if (result.action == RecommendedAction.useMinimumVersion) {
        expect(result.alternativeAction,
            RecommendedAction.leavePlanUnchanged);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Explanation
  // ---------------------------------------------------------------------------
  group('PersonalisedScorer — explanation', () {
    test('explanation is non-empty for all scenarios', () {
      final scenarios = [
        features(),
        features(
          ci: checkIn(energyLevel: EnergyLevel.high),
          logs: List.generate(
              4, (i) => completedLog(today.subtract(Duration(days: i + 1)))),
        ),
      ];
      for (final f in scenarios) {
        final result = scorer.evaluate(f);
        expect(result.explanation.isNotEmpty, isTrue);
        expect(result.explanation.length, greaterThan(20));
      }
    });

    test('explanation includes personalised score percentage', () {
      final result = scorer.evaluate(features());
      expect(result.explanation, contains('score'));
    });

    test('recovery data appears in explanation when sufficient', () {
      final result = scorer.evaluate(
        features(),
        recovery: goodRecovery(),
      );
      expect(result.explanation, contains('recovery rate'));
    });
  });

  // ---------------------------------------------------------------------------
  // Factors used / missing
  // ---------------------------------------------------------------------------
  group('PersonalisedScorer — factors', () {
    test('recovery_rate appears in factorsUsed when recovery is sufficient', () {
      final result = scorer.evaluate(
        features(),
        recovery: goodRecovery(),
      );
      expect(result.factorsUsed, contains('recovery_rate'));
    });

    test('recovery_rate absent from factorsUsed when insufficient', () {
      final result = scorer.evaluate(
        features(),
        recovery: const RecoveryMetrics(
          habitId: 'h1',
          observationCount: 2,
          isSufficient: false,
        ),
      );
      expect(result.factorsUsed, isNot(contains('recovery_rate')));
    });

    test('no-context result includes daily_check_in in missing factors', () {
      final result = scorer.evaluate(features());
      expect(result.factorsMissing, contains('daily_check_in'));
    });
  });
}
