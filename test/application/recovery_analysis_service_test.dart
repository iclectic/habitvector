import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/application/adaptive/recovery_analysis_service.dart';
import 'package:habit_flow/domain/entities/habit.dart';
import 'package:habit_flow/domain/entities/habit_log.dart';
import 'package:habit_flow/domain/entities/recovery_metrics.dart';

void main() {
  const service = RecoveryAnalysisService();
  final today = DateTime(2024, 6, 30);

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

  HabitLog completed(DateTime date) => HabitLog(
        id: 'c-${date.toIso8601String()}',
        habitId: 'h1',
        date: date,
        completed: true,
        createdAt: date,
      );

  HabitLog missed(DateTime date) => HabitLog(
        id: 'm-${date.toIso8601String()}',
        habitId: 'h1',
        date: date,
        completed: false,
        createdAt: date,
      );

  HabitLog skipped(DateTime date) => HabitLog(
        id: 's-${date.toIso8601String()}',
        habitId: 'h1',
        date: date,
        completed: false,
        skipped: true,
        createdAt: date,
      );

  // ---------------------------------------------------------------------------

  group('RecoveryAnalysisService — empty / no-miss cases', () {
    test('returns insufficient metrics when no logs', () {
      final m = service.calculate(habit: dailyHabit(), logs: [], today: today);
      expect(m.isSufficient, isFalse);
      expect(m.observationCount, 0);
      expect(m.recoveryRate, isNull);
    });

    test('returns metrics with no misses when all days completed', () {
      final logs = List.generate(
        10,
        (i) => completed(today.subtract(Duration(days: i + 1))),
      );
      final m = service.calculate(
          habit: dailyHabit(), logs: logs, today: today);
      expect(m.successfulRecoveries, 0);
      expect(m.lapsedAfterMiss, 0);
      expect(m.recoveryRate, isNull);
    });

    test('skipped days are not counted as misses', () {
      final logs = [
        completed(today.subtract(const Duration(days: 3))),
        skipped(today.subtract(const Duration(days: 2))),
        completed(today.subtract(const Duration(days: 1))),
      ];
      final m = service.calculate(
          habit: dailyHabit(), logs: logs, today: today);
      expect(m.successfulRecoveries, 0);
      expect(m.lapsedAfterMiss, 0);
    });
  });

  // ---------------------------------------------------------------------------

  group('RecoveryAnalysisService — single miss runs', () {
    test('miss then completion within 2 days = successful recovery', () {
      final logs = [
        completed(today.subtract(const Duration(days: 10))),
        missed(today.subtract(const Duration(days: 9))),
        completed(today.subtract(const Duration(days: 8))),
        completed(today.subtract(const Duration(days: 7))),
        completed(today.subtract(const Duration(days: 6))),
        completed(today.subtract(const Duration(days: 5))),
        completed(today.subtract(const Duration(days: 4))),
        completed(today.subtract(const Duration(days: 3))),
        completed(today.subtract(const Duration(days: 2))),
        completed(today.subtract(const Duration(days: 1))),
      ];
      final m = service.calculate(
          habit: dailyHabit(), logs: logs, today: today);
      expect(m.successfulRecoveries, 1);
      expect(m.lapsedAfterMiss, 0);
      expect(m.recoveryRate, closeTo(1.0, 0.001));
    });

    test('miss then no completion for 7+ days = lapse', () {
      // Miss 20 days ago, nothing after — well past lapse window.
      final logs = [
        completed(today.subtract(const Duration(days: 25))),
        missed(today.subtract(const Duration(days: 20))),
      ];
      final m = service.calculate(
          habit: dailyHabit(), logs: logs, today: today);
      expect(m.lapsedAfterMiss, 1);
      expect(m.successfulRecoveries, 0);
      expect(m.recoveryRate, closeTo(0.0, 0.001));
    });

    test('miss within lapse window is excluded from counts', () {
      // Miss 3 days ago — not yet past 7-day lapse window AND not recovered.
      final logs = [
        completed(today.subtract(const Duration(days: 5))),
        missed(today.subtract(const Duration(days: 3))),
      ];
      final m = service.calculate(
          habit: dailyHabit(), logs: logs, today: today);
      // Not resolved yet — should not count as lapse or recovery.
      expect(m.successfulRecoveries, 0);
      expect(m.lapsedAfterMiss, 0);
      expect(m.observationCount, 0);
    });
  });

  // ---------------------------------------------------------------------------

  group('RecoveryAnalysisService — multiple miss events', () {
    test('two separate miss-and-recover events both counted', () {
      final logs = [
        // Event 1: miss day 20, recover day 19.
        completed(today.subtract(const Duration(days: 22))),
        missed(today.subtract(const Duration(days: 21))),
        completed(today.subtract(const Duration(days: 20))),
        // Gap of completions.
        completed(today.subtract(const Duration(days: 15))),
        // Event 2: miss day 12, recover day 11.
        missed(today.subtract(const Duration(days: 13))),
        completed(today.subtract(const Duration(days: 12))),
        completed(today.subtract(const Duration(days: 11))),
        completed(today.subtract(const Duration(days: 10))),
      ];
      final m = service.calculate(
          habit: dailyHabit(), logs: logs, today: today);
      expect(m.successfulRecoveries, 2);
      expect(m.lapsedAfterMiss, 0);
    });

    test('one recovery and one lapse both counted', () {
      final logs = [
        // Recovery: miss 25 days ago, complete 24 days ago.
        completed(today.subtract(const Duration(days: 27))),
        missed(today.subtract(const Duration(days: 26))),
        completed(today.subtract(const Duration(days: 25))),
        // Lapse: miss 15 days ago, no completion after.
        completed(today.subtract(const Duration(days: 17))),
        missed(today.subtract(const Duration(days: 15))),
      ];
      final m = service.calculate(
          habit: dailyHabit(), logs: logs, today: today);
      expect(m.successfulRecoveries, 1);
      expect(m.lapsedAfterMiss, 1);
      expect(m.recoveryRate, closeTo(0.5, 0.001));
    });
  });

  // ---------------------------------------------------------------------------

  group('RecoveryAnalysisService — completionAfterOneMiss', () {
    test('single-miss recovery sets completionAfterOneMiss to 1.0', () {
      final logs = [
        completed(today.subtract(const Duration(days: 10))),
        missed(today.subtract(const Duration(days: 9))),
        completed(today.subtract(const Duration(days: 8))),
      ];
      final m = service.calculate(
          habit: dailyHabit(), logs: logs, today: today);
      expect(m.completionAfterOneMiss, closeTo(1.0, 0.001));
      expect(m.completionAfterTwoOrMoreMisses, isNull);
    });

    test('single-miss lapse sets completionAfterOneMiss to 0.0', () {
      final logs = [
        completed(today.subtract(const Duration(days: 25))),
        missed(today.subtract(const Duration(days: 20))),
      ];
      final m = service.calculate(
          habit: dailyHabit(), logs: logs, today: today);
      expect(m.completionAfterOneMiss, closeTo(0.0, 0.001));
    });
  });

  // ---------------------------------------------------------------------------

  group('RecoveryAnalysisService — isSufficient threshold', () {
    test('fewer than minimumObservations → isSufficient=false', () {
      // Create 4 resolvable miss events (2 recoveries + 2 lapses).
      final logs = <HabitLog>[];
      // 4 lapses, each > 7 days ago.
      for (int i = 0; i < 4; i++) {
        final base = 30 + i * 10;
        logs.add(completed(today.subtract(Duration(days: base + 2))));
        logs.add(missed(today.subtract(Duration(days: base))));
      }
      final m = service.calculate(
          habit: dailyHabit(), logs: logs, today: today);
      expect(m.observationCount, 4);
      expect(m.isSufficient, isFalse);
    });

    test('at least minimumObservations → isSufficient=true', () {
      // 5 single-miss lapses, each well past the lapse window.
      final logs = <HabitLog>[];
      for (int i = 0; i < 5; i++) {
        final base = 20 + i * 10;
        logs.add(completed(today.subtract(Duration(days: base + 2))));
        logs.add(missed(today.subtract(Duration(days: base))));
      }
      final m = service.calculate(
          habit: dailyHabit(), logs: logs, today: today);
      expect(m.observationCount, greaterThanOrEqualTo(RecoveryMetrics.minimumObservations));
      expect(m.isSufficient, isTrue);
    });
  });

  // ---------------------------------------------------------------------------

  group('RecoveryAnalysisService — resilienceTrend', () {
    test('trend is null when fewer than 3 recovery data points', () {
      final logs = [
        completed(today.subtract(const Duration(days: 15))),
        missed(today.subtract(const Duration(days: 14))),
        completed(today.subtract(const Duration(days: 13))),
      ];
      final m = service.calculate(
          habit: dailyHabit(), logs: logs, today: today);
      // Only 1 recovery — not enough for trend.
      expect(m.resilienceTrend, isNull);
    });

    test('trend is non-null with 3+ recovery data points', () {
      final logs = <HabitLog>[];
      // Create 3 separate miss-and-recover sequences.
      for (int i = 0; i < 3; i++) {
        final base = 10 + i * 15;
        logs.add(completed(today.subtract(Duration(days: base + 3))));
        logs.add(missed(today.subtract(Duration(days: base + 2))));
        logs.add(completed(today.subtract(Duration(days: base + 1))));
        logs.add(completed(today.subtract(Duration(days: base))));
      }
      final m = service.calculate(
          habit: dailyHabit(), logs: logs, today: today);
      expect(m.resilienceTrend, isNotNull);
    });
  });
}
