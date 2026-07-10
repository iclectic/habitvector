/// Abstraction over the system clock.
///
/// Inject this into any class that depends on the current time so that
/// time-dependent logic can be tested with a fixed or seeded clock.
abstract class Clock {
  const Clock();

  /// The current date and time in local time.
  DateTime now();

  /// Today's date with no time component (local time).
  DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }
}

/// Production implementation that delegates to [DateTime.now].
class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Test implementation backed by a fixed timestamp.
class FixedClock extends Clock {
  final DateTime _fixed;

  const FixedClock(this._fixed);

  @override
  DateTime now() => _fixed;
}
