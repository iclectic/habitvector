import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/domain/entities/recovery_metrics.dart';

void main() {
  group('RecoveryMetrics', () {
    test('recoveryRate returns null when no misses recorded', () {
      const metrics = RecoveryMetrics(habitId: 'h1');
      expect(metrics.recoveryRate, isNull);
    });

    test('recoveryRate calculates correctly', () {
      const metrics = RecoveryMetrics(
        habitId: 'h1',
        successfulRecoveries: 3,
        lapsedAfterMiss: 1,
      );
      expect(metrics.recoveryRate, closeTo(0.75, 0.001));
    });

    test('recoveryRate is 1.0 when all misses resulted in recovery', () {
      const metrics = RecoveryMetrics(
        habitId: 'h1',
        successfulRecoveries: 5,
        lapsedAfterMiss: 0,
      );
      expect(metrics.recoveryRate, closeTo(1.0, 0.001));
    });

    test('recoveryRate is 0.0 when no miss resulted in recovery', () {
      const metrics = RecoveryMetrics(
        habitId: 'h1',
        successfulRecoveries: 0,
        lapsedAfterMiss: 4,
      );
      expect(metrics.recoveryRate, closeTo(0.0, 0.001));
    });

    test('isSufficient reflects minimum observation threshold', () {
      const insufficient = RecoveryMetrics(
        habitId: 'h1',
        observationCount: RecoveryMetrics.minimumObservations - 1,
        isSufficient: false,
      );
      expect(insufficient.isSufficient, isFalse);

      const sufficient = RecoveryMetrics(
        habitId: 'h1',
        observationCount: RecoveryMetrics.minimumObservations,
        isSufficient: true,
      );
      expect(sufficient.isSufficient, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      const original = RecoveryMetrics(
        habitId: 'h1',
        successfulRecoveries: 3,
        lapsedAfterMiss: 1,
        averageDaysToRecover: 1.5,
        observationCount: 10,
        isSufficient: true,
      );

      final updated = original.copyWith(successfulRecoveries: 4);
      expect(updated.habitId, 'h1');
      expect(updated.successfulRecoveries, 4);
      expect(updated.lapsedAfterMiss, 1);
      expect(updated.averageDaysToRecover, closeTo(1.5, 0.001));
      expect(updated.isSufficient, isTrue);
    });
  });
}
