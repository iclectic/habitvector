import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/application/context/check_in_use_cases.dart';
import 'package:habit_flow/data/database/app_database.dart';
import 'package:habit_flow/data/repositories/drift_context_repository.dart';
import 'package:habit_flow/domain/entities/daily_check_in.dart';
import 'package:habit_flow/domain/services/clock.dart';

void main() {
  late AppDatabase db;
  late CheckInUseCases useCases;

  final fixedNow = DateTime(2024, 6, 15, 8, 30);
  final fixedToday = DateTime(2024, 6, 15);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    useCases = CheckInUseCases(
      repo: DriftContextRepository(db),
      clock: FixedClock(fixedNow),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('CheckInUseCases', () {
    test('save creates a new check-in when none exists for today', () async {
      final result = await useCases.saveCheckIn(
        energyLevel: EnergyLevel.high,
        workloadLevel: WorkloadLevel.light,
        dayType: DayType.restDay,
      );

      expect(result.id, isNotEmpty);
      expect(result.date, fixedToday);
      expect(result.energyLevel, EnergyLevel.high);
      expect(result.workloadLevel, WorkloadLevel.light);
      expect(result.dayType, DayType.restDay);
      expect(result.createdAt, fixedNow);
    });

    test('save updates existing check-in when one already exists', () async {
      await useCases.saveCheckIn(energyLevel: EnergyLevel.low);
      final updated =
          await useCases.saveCheckIn(energyLevel: EnergyLevel.high);

      final all = await DriftContextRepository(db).getAllCheckIns();
      expect(all.length, 1,
          reason: 'Update must not create a duplicate record');
      expect(updated.energyLevel, EnergyLevel.high);
    });

    test('getTodayCheckIn returns saved check-in', () async {
      await useCases.saveCheckIn(dayType: DayType.workday);
      final result = await useCases.getTodayCheckIn();

      expect(result, isNotNull);
      expect(result!.dayType, DayType.workday);
    });

    test('getTodayCheckIn returns null when nothing saved', () async {
      final result = await useCases.getTodayCheckIn();
      expect(result, isNull);
    });

    test('deleteTodayCheckIn removes the check-in', () async {
      await useCases.saveCheckIn(energyLevel: EnergyLevel.moderate);
      await useCases.deleteTodayCheckIn();

      final result = await useCases.getTodayCheckIn();
      expect(result, isNull);
    });

    test('deleteTodayCheckIn is safe when nothing exists', () async {
      await expectLater(useCases.deleteTodayCheckIn(), completes);
    });

    test('save validates confidenceScore range', () async {
      await expectLater(
        () => useCases.saveCheckIn(confidenceScore: 1.1),
        throwsArgumentError,
      );
      await expectLater(
        () => useCases.saveCheckIn(confidenceScore: -0.1),
        throwsArgumentError,
      );
    });

    test('save validates availableMinutes is non-negative', () async {
      await expectLater(
        () => useCases.saveCheckIn(availableMinutes: -1),
        throwsArgumentError,
      );
    });

    test('save stores all optional fields', () async {
      final result = await useCases.saveCheckIn(
        availableMinutes: 45,
        energyLevel: EnergyLevel.moderate,
        workloadLevel: WorkloadLevel.moderate,
        dayType: DayType.workday,
        shiftLabel: 'Day shift',
        challengePreference: ChallengePreference.normal,
        confidenceScore: 0.75,
        notes: 'Feeling okay today',
      );

      expect(result.availableMinutes, 45);
      expect(result.energyLevel, EnergyLevel.moderate);
      expect(result.workloadLevel, WorkloadLevel.moderate);
      expect(result.dayType, DayType.workday);
      expect(result.shiftLabel, 'Day shift');
      expect(result.challengePreference, ChallengePreference.normal);
      expect(result.confidenceScore, closeTo(0.75, 0.001));
      expect(result.notes, 'Feeling okay today');
    });

    test('getCheckInsInRange returns check-ins across multiple days', () async {
      // Simulate check-ins on different days by inserting directly.
      final repo = DriftContextRepository(db);
      for (var i = 0; i < 5; i++) {
        final d = DateTime(2024, 6, 10 + i);
        await repo.insertCheckIn(DailyCheckIn(
          id: 'ci$i',
          date: d,
          energyLevel: EnergyLevel.moderate,
          createdAt: d,
        ));
      }

      final results = await useCases.getCheckInsInRange(
        DateTime(2024, 6, 11),
        DateTime(2024, 6, 13),
      );
      expect(results.length, 3);
    });
  });
}
