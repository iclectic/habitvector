import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/application/experiments/friction_analyser.dart';
import 'package:habit_flow/domain/entities/daily_check_in.dart';
import 'package:habit_flow/domain/entities/habit.dart';
import 'package:habit_flow/domain/entities/habit_log.dart';

void main() {
  const analyser = FrictionAnalyser();
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

  HabitLog log(DateTime date, {bool completed = true, bool skipped = false}) =>
      HabitLog(
        id: 'l-${date.millisecondsSinceEpoch}',
        habitId: 'h1',
        date: date,
        completed: completed,
        skipped: skipped,
        createdAt: date,
      );

  DailyCheckIn checkIn(
    DateTime date, {
    EnergyLevel? energyLevel,
    WorkloadLevel? workloadLevel,
  }) =>
      DailyCheckIn(
        id: 'ci-${date.millisecondsSinceEpoch}',
        date: date,
        energyLevel: energyLevel,
        workloadLevel: workloadLevel,
        createdAt: date,
      );

  // ---------------------------------------------------------------------------
  // Empty / insufficient
  // ---------------------------------------------------------------------------
  group('FrictionAnalyser — insufficient data', () {
    test('no logs → isSufficient=false, no signals', () {
      final map = analyser.analyse(
          habit: dailyHabit(), logs: [], today: today);
      expect(map.isSufficient, isFalse);
      expect(map.signals, isEmpty);
    });

    test('fewer than 14 logs → isSufficient=false', () {
      final logs = List.generate(
        10,
        (i) => log(today.subtract(Duration(days: i + 1))),
      );
      final map = analyser.analyse(
          habit: dailyHabit(), logs: logs, today: today);
      expect(map.isSufficient, isFalse);
    });

    test('14+ logs → isSufficient=true', () {
      final logs = List.generate(
        14,
        (i) => log(today.subtract(Duration(days: i + 1))),
      );
      final map = analyser.analyse(
          habit: dailyHabit(), logs: logs, today: today);
      expect(map.isSufficient, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Skip rate
  // ---------------------------------------------------------------------------
  group('FrictionAnalyser — skip rate', () {
    test('skip rate is correct', () {
      final logs = [
        log(DateTime(2024, 6, 1), completed: true),
        log(DateTime(2024, 6, 2), completed: true),
        log(DateTime(2024, 6, 3), skipped: true, completed: false),
        log(DateTime(2024, 6, 4), skipped: true, completed: false),
        log(DateTime(2024, 6, 5), completed: true),
      ];
      final map = analyser.analyse(
          habit: dailyHabit(), logs: logs, today: today);
      expect(map.skipRate, closeTo(2 / 5, 0.001));
    });

    test('no skips → skip rate = 0', () {
      final logs = List.generate(
        14,
        (i) => log(today.subtract(Duration(days: i + 1))),
      );
      final map = analyser.analyse(
          habit: dailyHabit(), logs: logs, today: today);
      expect(map.skipRate, 0.0);
    });
  });

  // ---------------------------------------------------------------------------
  // High skip rate signal
  // ---------------------------------------------------------------------------
  group('FrictionAnalyser — high skip rate signal', () {
    test('skip rate ≥ 0.25 surfaces high skip rate signal', () {
      // 7/14 skipped (50%)
      final logs = [
        ...List.generate(7, (i) => log(DateTime(2024, 6, 1 + i))),
        ...List.generate(
          7,
          (i) => log(DateTime(2024, 6, 8 + i),
              skipped: true, completed: false),
        ),
      ];
      final map = analyser.analyse(
          habit: dailyHabit(), logs: logs, today: today);
      final signal = map.signals
          .where((s) => s.category == FrictionCategory.highSkipRate)
          .firstOrNull;
      expect(signal, isNotNull);
    });

    test('skip rate < 0.25 does not surface high skip rate signal', () {
      // 2/14 skipped (~14%)
      final logs = [
        ...List.generate(12, (i) => log(DateTime(2024, 6, 1 + i))),
        ...List.generate(
          2,
          (i) => log(DateTime(2024, 6, 13 + i),
              skipped: true, completed: false),
        ),
      ];
      final map = analyser.analyse(
          habit: dailyHabit(), logs: logs, today: today);
      final signal = map.signals
          .where((s) => s.category == FrictionCategory.highSkipRate)
          .firstOrNull;
      expect(signal, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Day-of-week pattern
  // ---------------------------------------------------------------------------
  group('FrictionAnalyser — day-of-week pattern', () {
    test('cluster of misses on specific weekday surfaces a signal', () {
      // Monday = weekday 1. Build 4 Mondays with high miss rate.
      // Mondays in June 2024: 3, 10, 17, 24.
      // Plus fill with completions on other days (at least 14 total).
      final logs = <HabitLog>[];

      // 4 Mondays — all missed
      for (final d in [3, 10, 17, 24]) {
        logs.add(log(DateTime(2024, 6, d), completed: false));
      }
      // 10 other days — completed
      for (final d in [4, 5, 6, 7, 11, 12, 13, 14, 18, 19]) {
        logs.add(log(DateTime(2024, 6, d)));
      }

      final map = analyser.analyse(
          habit: dailyHabit(), logs: logs, today: today);
      final dayOfWeekSignals = map.signals
          .where((s) => s.category == FrictionCategory.dayOfWeekPattern)
          .toList();
      expect(dayOfWeekSignals, isNotEmpty,
          reason: 'Should detect Monday friction pattern');
      expect(dayOfWeekSignals.first.label.toLowerCase(), contains('monday'));
    });
  });

  // ---------------------------------------------------------------------------
  // Weekend drift
  // ---------------------------------------------------------------------------
  group('FrictionAnalyser — weekend drift', () {
    test('high weekend miss rate surfaces weekend drift signal', () {
      final logs = <HabitLog>[];
      // Weekdays: June 3-7, 10-14 (10 days) — all completed
      for (final d in [3, 4, 5, 6, 7, 10, 11, 12, 13, 14]) {
        logs.add(log(DateTime(2024, 6, d)));
      }
      // Weekends: June 1-2, 8-9, 15-16 (6 days) — all missed
      for (final d in [1, 2, 8, 9, 15, 16]) {
        logs.add(log(DateTime(2024, 6, d), completed: false));
      }

      final map = analyser.analyse(
          habit: dailyHabit(), logs: logs, today: today);
      final signal = map.signals
          .where((s) => s.category == FrictionCategory.weekendDrift)
          .firstOrNull;
      expect(signal, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Energy pattern (requires check-ins)
  // ---------------------------------------------------------------------------
  group('FrictionAnalyser — energy pattern', () {
    test('low energy days with high miss rate surfaces energy signal', () {
      final logs = <HabitLog>[];
      final cis = <DailyCheckIn>[];

      // 10 normal days — completed + normal energy
      for (int i = 0; i < 10; i++) {
        final d = DateTime(2024, 6, 1 + i);
        logs.add(log(d));
        cis.add(checkIn(d, energyLevel: EnergyLevel.high));
      }
      // 4 low energy days — all missed
      for (int i = 0; i < 4; i++) {
        final d = DateTime(2024, 6, 11 + i);
        logs.add(log(d, completed: false));
        cis.add(checkIn(d, energyLevel: EnergyLevel.veryLow));
      }

      final map = analyser.analyse(
        habit: dailyHabit(),
        logs: logs,
        checkIns: cis,
        today: today,
      );
      final signal = map.signals
          .where((s) => s.category == FrictionCategory.energyPattern)
          .firstOrNull;
      expect(signal, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Workload pattern (requires check-ins)
  // ---------------------------------------------------------------------------
  group('FrictionAnalyser — workload pattern', () {
    test('high workload days with high miss rate surfaces workload signal', () {
      final logs = <HabitLog>[];
      final cis = <DailyCheckIn>[];

      // 10 light workload days — completed
      for (int i = 0; i < 10; i++) {
        final d = DateTime(2024, 6, 1 + i);
        logs.add(log(d));
        cis.add(checkIn(d, workloadLevel: WorkloadLevel.light));
      }
      // 4 overwhelming days — all missed
      for (int i = 0; i < 4; i++) {
        final d = DateTime(2024, 6, 11 + i);
        logs.add(log(d, completed: false));
        cis.add(checkIn(d, workloadLevel: WorkloadLevel.overwhelming));
      }

      final map = analyser.analyse(
        habit: dailyHabit(),
        logs: logs,
        checkIns: cis,
        today: today,
      );
      final signal = map.signals
          .where((s) => s.category == FrictionCategory.workloadPattern)
          .firstOrNull;
      expect(signal, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Signal intensity and ordering
  // ---------------------------------------------------------------------------
  group('FrictionAnalyser — signal ordering', () {
    test('signals are sorted by descending intensity', () {
      // Build a scenario that generates multiple signals.
      final logs = <HabitLog>[];
      // All skipped (50%) — triggers high skip rate + day patterns.
      for (int i = 0; i < 7; i++) {
        logs.add(log(DateTime(2024, 6, 1 + i)));
      }
      for (int i = 0; i < 7; i++) {
        logs.add(log(DateTime(2024, 6, 8 + i),
            skipped: true, completed: false));
      }
      final map = analyser.analyse(
          habit: dailyHabit(), logs: logs, today: today);
      for (int i = 1; i < map.signals.length; i++) {
        expect(map.signals[i].intensity,
            lessThanOrEqualTo(map.signals[i - 1].intensity),
            reason: 'Signals should be sorted by descending intensity');
      }
    });

    test('intensity is between 0.0 and 1.0 for all signals', () {
      final logs = <HabitLog>[];
      for (int i = 0; i < 14; i++) {
        final completed = i % 3 != 0;
        final skipped = !completed && i % 2 == 0;
        logs.add(log(DateTime(2024, 6, 1 + i),
            completed: completed, skipped: skipped));
      }
      final map = analyser.analyse(
          habit: dailyHabit(), logs: logs, today: today);
      for (final signal in map.signals) {
        expect(signal.intensity, greaterThanOrEqualTo(0.0));
        expect(signal.intensity, lessThanOrEqualTo(1.0));
      }
    });
  });
}
