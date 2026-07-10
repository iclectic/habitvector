import 'package:drift/drift.dart';
import '../../domain/entities/daily_check_in.dart';
import '../database/app_database.dart';

/// Maps between domain [DailyCheckIn] entity and Drift [DailyCheckInRow].
class CheckInMapper {
  static DailyCheckIn toDomain(DailyCheckInRow db) {
    return DailyCheckIn(
      id: db.id,
      date: db.date,
      availableMinutes: db.availableMinutes,
      energyLevel: db.energyLevel != null
          ? EnergyLevel.values[db.energyLevel!]
          : null,
      workloadLevel: db.workloadLevel != null
          ? WorkloadLevel.values[db.workloadLevel!]
          : null,
      dayType:
          db.dayType != null ? DayType.values[db.dayType!] : null,
      shiftLabel: db.shiftLabel,
      challengePreference: db.challengePreference != null
          ? ChallengePreference.values[db.challengePreference!]
          : null,
      confidenceScore: db.confidenceScore,
      notes: db.notes,
      createdAt: db.createdAt,
    );
  }

  static DailyCheckInsCompanion toCompanion(DailyCheckIn c) {
    return DailyCheckInsCompanion.insert(
      id: c.id,
      date: DateTime(c.date.year, c.date.month, c.date.day),
      createdAt: c.createdAt,
    ).copyWith(
      availableMinutes: c.availableMinutes != null
          ? Value(c.availableMinutes)
          : const Value(null),
      energyLevel: c.energyLevel != null
          ? Value(c.energyLevel!.index)
          : const Value(null),
      workloadLevel: c.workloadLevel != null
          ? Value(c.workloadLevel!.index)
          : const Value(null),
      dayType:
          c.dayType != null ? Value(c.dayType!.index) : const Value(null),
      shiftLabel:
          c.shiftLabel != null ? Value(c.shiftLabel) : const Value(null),
      challengePreference: c.challengePreference != null
          ? Value(c.challengePreference!.index)
          : const Value(null),
      confidenceScore: c.confidenceScore != null
          ? Value(c.confidenceScore)
          : const Value(null),
      notes: c.notes != null ? Value(c.notes) : const Value(null),
    );
  }
}
