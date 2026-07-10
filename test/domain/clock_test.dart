import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/domain/services/clock.dart';

void main() {
  group('SystemClock', () {
    test('now() returns a datetime close to the real current time', () {
      const clock = SystemClock();
      final before = DateTime.now();
      final result = clock.now();
      final after = DateTime.now();
      expect(result.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('today() has no time component', () {
      const clock = SystemClock();
      final today = clock.today();
      expect(today.hour, 0);
      expect(today.minute, 0);
      expect(today.second, 0);
    });
  });

  group('FixedClock', () {
    test('now() always returns the fixed datetime', () {
      final fixed = DateTime(2024, 6, 15, 14, 30);
      final clock = FixedClock(fixed);
      expect(clock.now(), fixed);
      expect(clock.now(), fixed);
    });

    test('today() strips time from fixed datetime', () {
      final fixed = DateTime(2024, 6, 15, 14, 30, 45);
      final clock = FixedClock(fixed);
      expect(clock.today(), DateTime(2024, 6, 15));
    });
  });
}
