import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/domain/entities/habit_versions.dart';

void main() {
  final now = DateTime(2024, 6, 1);

  HabitVersions makeVersions({
    String? minimumDescription,
    int? minimumDurationMinutes,
    String? stretchDescription,
    int? stretchDurationMinutes,
  }) {
    return HabitVersions(
      id: 'hv1',
      habitId: 'h1',
      minimumDescription: minimumDescription,
      minimumDurationMinutes: minimumDurationMinutes,
      stretchDescription: stretchDescription,
      stretchDurationMinutes: stretchDurationMinutes,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('HabitVersions', () {
    test('hasMinimum is false when both minimum fields are null', () {
      final v = makeVersions();
      expect(v.hasMinimum, isFalse);
    });

    test('hasMinimum is true when description is set', () {
      final v = makeVersions(minimumDescription: '5-min walk');
      expect(v.hasMinimum, isTrue);
    });

    test('hasMinimum is true when duration is set', () {
      final v = makeVersions(minimumDurationMinutes: 5);
      expect(v.hasMinimum, isTrue);
    });

    test('hasStretch is false when both stretch fields are null', () {
      final v = makeVersions();
      expect(v.hasStretch, isFalse);
    });

    test('hasStretch is true when stretch description is set', () {
      final v = makeVersions(stretchDescription: '40-min walk');
      expect(v.hasStretch, isTrue);
    });

    test('copyWith updates only specified fields', () {
      final v = makeVersions(
        minimumDescription: '5-min walk',
        minimumDurationMinutes: 5,
      );
      final updated = v.copyWith(minimumDurationMinutes: 10);

      expect(updated.minimumDescription, '5-min walk');
      expect(updated.minimumDurationMinutes, 10);
      expect(updated.stretchDescription, isNull);
    });

    test('copyWith with clear flags nulls optional fields', () {
      final v = makeVersions(
        minimumDescription: '5-min walk',
        minimumDurationMinutes: 5,
      );
      final cleared = v.copyWith(clearMinimumDescription: true);

      expect(cleared.minimumDescription, isNull);
      expect(cleared.minimumDurationMinutes, 5);
    });

    test('equality is based on id', () {
      final v1 = makeVersions(minimumDescription: 'A');
      final v2 = makeVersions(minimumDescription: 'B');
      expect(v1, equals(v2)); // same id 'hv1'
    });
  });
}
