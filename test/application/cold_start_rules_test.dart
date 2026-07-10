import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/application/adaptive/cold_start_rules.dart';
import 'package:habit_flow/application/adaptive/context_feature_builder.dart';
import 'package:habit_flow/domain/entities/adaptive_recommendation.dart';
import 'package:habit_flow/domain/entities/daily_check_in.dart';
import 'package:habit_flow/domain/entities/habit.dart';
import 'package:habit_flow/domain/entities/habit_log.dart';
import 'package:habit_flow/domain/entities/habit_versions.dart';
import 'package:habit_flow/domain/entities/work_shift.dart';

void main() {
  final rules = const ColdStartRules();
  final today = DateTime(2024, 6, 15);

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Habit dailyHabit({String id = 'h1'}) => Habit(
        id: id,
        title: 'Test Habit',
        colourValue: 0xFF6366F1,
        iconCodePoint: 0xe3c9,
        scheduleType: ScheduleType.daily,
        goalType: GoalType.tick,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  HabitLog completedLog(DateTime date) => HabitLog(
        id: 'log-${date.toIso8601String()}',
        habitId: 'h1',
        date: date,
        completed: true,
        createdAt: date,
      );

  HabitLog missedLog(DateTime date) => HabitLog(
        id: 'log-miss-${date.toIso8601String()}',
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
    double? confidenceScore,
  }) =>
      DailyCheckIn(
        id: 'ci1',
        date: today,
        energyLevel: energyLevel,
        workloadLevel: workloadLevel,
        dayType: dayType,
        availableMinutes: availableMinutes,
        confidenceScore: confidenceScore,
        createdAt: today,
      );

  ContextFeatures features({
    DailyCheckIn? checkIn,
    WorkShift? todayShift,
    List<HabitLog>? recentLogs,
    Habit? habit,
  }) =>
      ContextFeatures(
        habit: habit ?? dailyHabit(),
        today: today,
        recentLogs: recentLogs ?? [],
        checkIn: checkIn,
        todayShift: todayShift,
      );

  // ---------------------------------------------------------------------------
  // Rule 1: Extended consecutive misses
  // ---------------------------------------------------------------------------
  group('Rule 1 — extended consecutive misses', () {
    test('3 consecutive misses triggers recovery day recommendation', () {
      final logs = [
        missedLog(today.subtract(const Duration(days: 1))),
        missedLog(today.subtract(const Duration(days: 2))),
        missedLog(today.subtract(const Duration(days: 3))),
      ];
      final result = rules.evaluate(features(recentLogs: logs));

      expect(result.action, RecommendedAction.scheduleRecoveryDay);
      expect(result.alternativeAction, RecommendedAction.useMinimumVersion);
    });

    test('4 consecutive misses also triggers recovery', () {
      final logs = List.generate(
        4,
        (i) => missedLog(today.subtract(Duration(days: i + 1))),
      );
      final result = rules.evaluate(features(recentLogs: logs));
      expect(result.action, RecommendedAction.scheduleRecoveryDay);
    });

    test('2 consecutive misses does not trigger recovery rule', () {
      final logs = [
        missedLog(today.subtract(const Duration(days: 1))),
        missedLog(today.subtract(const Duration(days: 2))),
        completedLog(today.subtract(const Duration(days: 3))),
      ];
      final result = rules.evaluate(features(recentLogs: logs));
      expect(result.action, isNot(RecommendedAction.scheduleRecoveryDay));
    });
  });

  // ---------------------------------------------------------------------------
  // Rule 2: Low energy + high workload
  // ---------------------------------------------------------------------------
  group('Rule 2 — low energy AND high workload', () {
    test('very_low energy + heavy workload → minimum version', () {
      final ci = checkIn(
        energyLevel: EnergyLevel.veryLow,
        workloadLevel: WorkloadLevel.heavy,
      );
      final result = rules.evaluate(features(checkIn: ci));

      expect(result.action, RecommendedAction.useMinimumVersion);
      expect(result.suggestedVersion, HabitVersionLevel.minimum);
    });

    test('low energy + overwhelming workload → minimum version', () {
      final ci = checkIn(
        energyLevel: EnergyLevel.low,
        workloadLevel: WorkloadLevel.overwhelming,
      );
      final result = rules.evaluate(features(checkIn: ci));

      expect(result.action, RecommendedAction.useMinimumVersion);
      expect(result.suggestedVersion, HabitVersionLevel.minimum);
    });

    test('moderate energy + heavy workload does NOT trigger rule 2', () {
      final ci = checkIn(
        energyLevel: EnergyLevel.moderate,
        workloadLevel: WorkloadLevel.heavy,
      );
      final result = rules.evaluate(features(checkIn: ci));
      expect(result.action, isNot(RecommendedAction.scheduleRecoveryDay));
      // falls through to rule 4 (high workload)
      expect(result.action, RecommendedAction.useMinimumVersion);
    });
  });

  // ---------------------------------------------------------------------------
  // Rule 3: Low energy only
  // ---------------------------------------------------------------------------
  group('Rule 3 — low energy only', () {
    test('very low energy + light workload → minimum version', () {
      final ci = checkIn(
        energyLevel: EnergyLevel.veryLow,
        workloadLevel: WorkloadLevel.light,
      );
      final result = rules.evaluate(features(checkIn: ci));
      expect(result.action, RecommendedAction.useMinimumVersion);
    });

    test('low energy + moderate workload → minimum version', () {
      final ci = checkIn(
        energyLevel: EnergyLevel.low,
        workloadLevel: WorkloadLevel.moderate,
      );
      final result = rules.evaluate(features(checkIn: ci));
      expect(result.action, RecommendedAction.useMinimumVersion);
    });

    test('moderate energy is not low energy', () {
      final ci = checkIn(energyLevel: EnergyLevel.moderate);
      final result = rules.evaluate(features(checkIn: ci));
      // With no other triggers, should default to standard
      expect(result.action, RecommendedAction.completeStandard);
    });
  });

  // ---------------------------------------------------------------------------
  // Rule 4: High workload only
  // ---------------------------------------------------------------------------
  group('Rule 4 — high workload only', () {
    test('heavy workload + moderate energy → minimum version', () {
      final ci = checkIn(
        energyLevel: EnergyLevel.moderate,
        workloadLevel: WorkloadLevel.heavy,
      );
      final result = rules.evaluate(features(checkIn: ci));
      expect(result.action, RecommendedAction.useMinimumVersion);
    });

    test('overwhelming workload + high energy → minimum version', () {
      final ci = checkIn(
        energyLevel: EnergyLevel.high,
        workloadLevel: WorkloadLevel.overwhelming,
      );
      final result = rules.evaluate(features(checkIn: ci));
      expect(result.action, RecommendedAction.useMinimumVersion);
    });

    test('moderate workload does not trigger rule 4', () {
      final ci = checkIn(workloadLevel: WorkloadLevel.moderate);
      final result = rules.evaluate(features(checkIn: ci));
      expect(result.action, RecommendedAction.completeStandard);
    });
  });

  // ---------------------------------------------------------------------------
  // Rule 5: Time-limited
  // ---------------------------------------------------------------------------
  group('Rule 5 — time-limited day', () {
    test('10 available minutes → minimum version', () {
      final ci = checkIn(availableMinutes: 10);
      final result = rules.evaluate(features(checkIn: ci));
      expect(result.action, RecommendedAction.useMinimumVersion);
      expect(result.alternativeAction, RecommendedAction.moveToAnotherTime);
    });

    test('14 available minutes → minimum version', () {
      final ci = checkIn(availableMinutes: 14);
      final result = rules.evaluate(features(checkIn: ci));
      expect(result.action, RecommendedAction.useMinimumVersion);
    });

    test('15 available minutes is NOT time-limited', () {
      final ci = checkIn(availableMinutes: 15);
      final result = rules.evaluate(features(checkIn: ci));
      // 15 minutes is the threshold; should not trigger rule 5
      expect(result.action, RecommendedAction.completeStandard);
    });

    test('60 available minutes is not time-limited', () {
      final ci = checkIn(availableMinutes: 60);
      final result = rules.evaluate(features(checkIn: ci));
      expect(result.action, RecommendedAction.completeStandard);
    });
  });

  // ---------------------------------------------------------------------------
  // Rule 6: Shift day + low confidence
  // ---------------------------------------------------------------------------
  group('Rule 6 — shift day with low confidence', () {
    test('shift day + confidence 0.3 → move to another time', () {
      final shift = WorkShift(
        id: 'ws1',
        label: 'Night shift',
        startTime: DateTime(2024, 6, 15, 22),
        endTime: DateTime(2024, 6, 16, 6),
        isOvernight: true,
        createdAt: today,
        updatedAt: today,
      );
      final ci = checkIn(confidenceScore: 0.3);
      final result = rules.evaluate(features(checkIn: ci, todayShift: shift));
      expect(result.action, RecommendedAction.moveToAnotherTime);
    });

    test('shift day + confidence 0.4 does not trigger rule 6', () {
      final shift = WorkShift(
        id: 'ws1',
        label: 'Day shift',
        startTime: DateTime(2024, 6, 15, 7),
        endTime: DateTime(2024, 6, 15, 15),
        createdAt: today,
        updatedAt: today,
      );
      final ci = checkIn(confidenceScore: 0.4);
      final result = rules.evaluate(features(checkIn: ci, todayShift: shift));
      expect(result.action, RecommendedAction.completeStandard);
    });

    test('shift day type (no shift object) + low confidence → move to another time',
        () {
      final ci = checkIn(dayType: DayType.shiftDay, confidenceScore: 0.2);
      final result = rules.evaluate(features(checkIn: ci));
      expect(result.action, RecommendedAction.moveToAnotherTime);
    });
  });

  // ---------------------------------------------------------------------------
  // Rule 7: Rest day with good recent history
  // ---------------------------------------------------------------------------
  group('Rule 7 — rest day with good recent history', () {
    test('rest day + 3+ completions last 7 days + not low energy → stretch', () {
      final recentLogs = List.generate(
        4,
        (i) => completedLog(today.subtract(Duration(days: i + 1))),
      );
      final ci = checkIn(
        dayType: DayType.restDay,
        energyLevel: EnergyLevel.high,
      );
      final result =
          rules.evaluate(features(checkIn: ci, recentLogs: recentLogs));
      expect(result.action, RecommendedAction.attemptStretchVersion);
      expect(result.suggestedVersion, HabitVersionLevel.stretch);
    });

    test('rest day + only 2 completions last 7 days → no stretch', () {
      final recentLogs = [
        completedLog(today.subtract(const Duration(days: 1))),
        completedLog(today.subtract(const Duration(days: 2))),
      ];
      final ci = checkIn(
        dayType: DayType.restDay,
        energyLevel: EnergyLevel.high,
      );
      final result =
          rules.evaluate(features(checkIn: ci, recentLogs: recentLogs));
      expect(result.action, RecommendedAction.completeStandard);
    });

    test('rest day + low energy → no stretch (falls through to default)', () {
      final recentLogs = List.generate(
        5,
        (i) => completedLog(today.subtract(Duration(days: i + 1))),
      );
      final ci = checkIn(
        dayType: DayType.restDay,
        energyLevel: EnergyLevel.veryLow,
      );
      // Low energy triggers rule 3 before rule 7.
      final result =
          rules.evaluate(features(checkIn: ci, recentLogs: recentLogs));
      expect(result.action, RecommendedAction.useMinimumVersion);
    });
  });

  // ---------------------------------------------------------------------------
  // Rule 8: After 1–2 consecutive misses
  // ---------------------------------------------------------------------------
  group('Rule 8 — 1–2 consecutive misses', () {
    test('1 miss → standard with recovery framing', () {
      final logs = [
        missedLog(today.subtract(const Duration(days: 1))),
        completedLog(today.subtract(const Duration(days: 2))),
      ];
      final result = rules.evaluate(features(recentLogs: logs));
      expect(result.action, RecommendedAction.completeStandard);
      expect(result.suggestedVersion, HabitVersionLevel.standard);
    });

    test('2 misses → standard with recovery framing', () {
      final logs = [
        missedLog(today.subtract(const Duration(days: 1))),
        missedLog(today.subtract(const Duration(days: 2))),
        completedLog(today.subtract(const Duration(days: 3))),
      ];
      final result = rules.evaluate(features(recentLogs: logs));
      expect(result.action, RecommendedAction.completeStandard);
    });
  });

  // ---------------------------------------------------------------------------
  // Default: complete standard
  // ---------------------------------------------------------------------------
  group('Default rule — no specific conditions', () {
    test('no check-in, no logs → default standard recommendation', () {
      final result = rules.evaluate(features());
      expect(result.action, RecommendedAction.completeStandard);
    });

    test('high energy + light workload → default standard', () {
      final ci = checkIn(
        energyLevel: EnergyLevel.high,
        workloadLevel: WorkloadLevel.light,
      );
      final result = rules.evaluate(features(checkIn: ci));
      expect(result.action, RecommendedAction.completeStandard);
    });

    test('very high energy → default standard', () {
      final ci = checkIn(energyLevel: EnergyLevel.veryHigh);
      final result = rules.evaluate(features(checkIn: ci));
      expect(result.action, RecommendedAction.completeStandard);
    });
  });

  // ---------------------------------------------------------------------------
  // Confidence bounds
  // ---------------------------------------------------------------------------
  group('Confidence bounds', () {
    test('confidence is always between 0.30 and 0.75', () {
      final scenarios = [
        features(),
        features(
          checkIn: checkIn(
            energyLevel: EnergyLevel.veryLow,
            workloadLevel: WorkloadLevel.overwhelming,
            availableMinutes: 5,
          ),
        ),
        features(
          recentLogs: List.generate(
            7,
            (i) => completedLog(today.subtract(Duration(days: i + 1))),
          ),
          checkIn: checkIn(
            dayType: DayType.restDay,
            energyLevel: EnergyLevel.veryHigh,
          ),
        ),
        features(
          recentLogs: List.generate(
            4,
            (i) => missedLog(today.subtract(Duration(days: i + 1))),
          ),
        ),
      ];

      for (final f in scenarios) {
        final result = rules.evaluate(f);
        expect(result.confidence, greaterThanOrEqualTo(0.30),
            reason: 'Confidence should never drop below 0.30');
        expect(result.confidence, lessThanOrEqualTo(0.75),
            reason: 'Confidence should never exceed 0.75 for cold-start');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Factors used / missing
  // ---------------------------------------------------------------------------
  group('Factors used and missing', () {
    test('factors used includes check-in when provided', () {
      final ci = checkIn(energyLevel: EnergyLevel.moderate);
      final result = rules.evaluate(features(checkIn: ci));
      expect(result.factorsUsed, contains('daily_check_in'));
      expect(result.factorsUsed, contains('energy_level'));
    });

    test('factors missing includes daily_check_in when absent', () {
      final result = rules.evaluate(features());
      expect(result.factorsMissing, contains('daily_check_in'));
    });

    test('factors missing includes completion_history when no logs', () {
      final result = rules.evaluate(features());
      expect(result.factorsMissing, contains('completion_history'));
    });

    test('factors used includes completion_history when logs present', () {
      final logs = [completedLog(today.subtract(const Duration(days: 1)))];
      final result = rules.evaluate(features(recentLogs: logs));
      expect(result.factorsUsed, contains('completion_history'));
    });
  });

  // ---------------------------------------------------------------------------
  // Explanation quality
  // ---------------------------------------------------------------------------
  group('Explanation content', () {
    test('explanation is non-empty for all rules', () {
      final scenarios = [
        features(),
        features(checkIn: checkIn(energyLevel: EnergyLevel.veryLow)),
        features(
            checkIn: checkIn(workloadLevel: WorkloadLevel.overwhelming)),
        features(checkIn: checkIn(availableMinutes: 5)),
        features(
            recentLogs: List.generate(
                4, (i) => missedLog(today.subtract(Duration(days: i + 1))))),
      ];

      for (final f in scenarios) {
        final result = rules.evaluate(f);
        expect(result.explanation.isNotEmpty, isTrue,
            reason: 'Explanation must never be empty');
        expect(result.explanation.length, greaterThan(20),
            reason: 'Explanation must be meaningful');
      }
    });

    test('no-check-in explanation includes sparse-data note', () {
      final result = rules.evaluate(features());
      expect(result.explanation,
          contains('No daily check-in was available'));
    });
  });
}
