import 'package:uuid/uuid.dart';

import '../../domain/entities/daily_check_in.dart';
import '../../domain/repositories/context_repository.dart';
import '../../domain/services/clock.dart';

/// Use cases for daily context check-in management.
///
/// Check-ins are entirely optional. The system works without them —
/// recommendations fall back to cold-start rules with a data-sparse note
/// in the explanation.
class CheckInUseCases {
  final ContextRepository _repo;
  final Clock _clock;
  final Uuid _uuid;

  CheckInUseCases({
    required ContextRepository repo,
    Clock clock = const SystemClock(),
    Uuid? uuid,
  })  : _repo = repo,
        _clock = clock,
        _uuid = uuid ?? const Uuid();

  /// Save or update today's check-in.
  ///
  /// If a check-in already exists for today, it is updated.
  /// If not, a new one is created.
  ///
  /// Returns the saved [DailyCheckIn].
  Future<DailyCheckIn> saveCheckIn({
    int? availableMinutes,
    EnergyLevel? energyLevel,
    WorkloadLevel? workloadLevel,
    DayType? dayType,
    String? shiftLabel,
    ChallengePreference? challengePreference,
    double? confidenceScore,
    String? notes,
  }) async {
    if (availableMinutes != null && availableMinutes < 0) {
      throw ArgumentError.value(
          availableMinutes, 'availableMinutes', 'Must be non-negative');
    }
    if (confidenceScore != null &&
        (confidenceScore < 0.0 || confidenceScore > 1.0)) {
      throw ArgumentError.value(
          confidenceScore, 'confidenceScore', 'Must be between 0.0 and 1.0');
    }

    final today = _clock.today();
    final existing = await _repo.getCheckInForDate(today);

    if (existing != null) {
      final updated = existing.copyWith(
        availableMinutes: availableMinutes,
        clearAvailableMinutes: availableMinutes == null,
        energyLevel: energyLevel,
        clearEnergyLevel: energyLevel == null,
        workloadLevel: workloadLevel,
        clearWorkloadLevel: workloadLevel == null,
        dayType: dayType,
        clearDayType: dayType == null,
        shiftLabel: shiftLabel,
        clearShiftLabel: shiftLabel == null,
        challengePreference: challengePreference,
        clearChallengePreference: challengePreference == null,
        confidenceScore: confidenceScore,
        clearConfidenceScore: confidenceScore == null,
        notes: notes,
        clearNotes: notes == null,
      );
      await _repo.updateCheckIn(updated);
      return updated;
    }

    final newCheckIn = DailyCheckIn(
      id: _uuid.v4(),
      date: today,
      availableMinutes: availableMinutes,
      energyLevel: energyLevel,
      workloadLevel: workloadLevel,
      dayType: dayType,
      shiftLabel: shiftLabel,
      challengePreference: challengePreference,
      confidenceScore: confidenceScore,
      notes: notes,
      createdAt: _clock.now(),
    );
    await _repo.insertCheckIn(newCheckIn);
    return newCheckIn;
  }

  /// Get today's check-in, or null if none was submitted.
  Future<DailyCheckIn?> getTodayCheckIn() =>
      _repo.getCheckInForDate(_clock.today());

  /// Watch today's check-in as a stream.
  Stream<DailyCheckIn?> watchTodayCheckIn() =>
      _repo.watchCheckInForDate(_clock.today());

  /// Get check-ins in a date range (for pattern analysis).
  Future<List<DailyCheckIn>> getCheckInsInRange(
          DateTime start, DateTime end) =>
      _repo.getCheckInsInRange(start, end);

  /// Delete today's check-in (user-initiated, e.g. undo).
  Future<void> deleteTodayCheckIn() async {
    final existing = await _repo.getCheckInForDate(_clock.today());
    if (existing != null) {
      await _repo.deleteCheckIn(existing.id);
    }
  }
}
