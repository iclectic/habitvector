/// Energy level self-report category.
enum EnergyLevel {
  veryLow,
  low,
  moderate,
  high,
  veryHigh,
}

/// Workload self-report category.
enum WorkloadLevel {
  light,
  moderate,
  heavy,
  overwhelming,
}

/// The type of day from the user's perspective.
enum DayType {
  workday,
  restDay,
  shiftDay,
  studyDay,
  other,
}

/// Challenge preference for the day.
enum ChallengePreference {
  minimal,
  normal,
  stretch,
}

/// Optional daily context check-in.
///
/// All fields are optional. Users may complete none, some, or all of them.
/// This is never treated as medical data.
class DailyCheckIn {
  final String id;
  final DateTime date;
  final int? availableMinutes;
  final EnergyLevel? energyLevel;
  final WorkloadLevel? workloadLevel;
  final DayType? dayType;
  final String? shiftLabel;
  final ChallengePreference? challengePreference;
  final double? confidenceScore; // 0.0–1.0, user self-report
  final String? notes; // free text, never sent externally
  final DateTime createdAt;

  const DailyCheckIn({
    required this.id,
    required this.date,
    this.availableMinutes,
    this.energyLevel,
    this.workloadLevel,
    this.dayType,
    this.shiftLabel,
    this.challengePreference,
    this.confidenceScore,
    this.notes,
    required this.createdAt,
  });

  /// Normalised date with no time component.
  DateTime get normalisedDate => DateTime(date.year, date.month, date.day);

  DailyCheckIn copyWith({
    String? id,
    DateTime? date,
    int? availableMinutes,
    bool clearAvailableMinutes = false,
    EnergyLevel? energyLevel,
    bool clearEnergyLevel = false,
    WorkloadLevel? workloadLevel,
    bool clearWorkloadLevel = false,
    DayType? dayType,
    bool clearDayType = false,
    String? shiftLabel,
    bool clearShiftLabel = false,
    ChallengePreference? challengePreference,
    bool clearChallengePreference = false,
    double? confidenceScore,
    bool clearConfidenceScore = false,
    String? notes,
    bool clearNotes = false,
    DateTime? createdAt,
  }) {
    return DailyCheckIn(
      id: id ?? this.id,
      date: date ?? this.date,
      availableMinutes: clearAvailableMinutes
          ? null
          : (availableMinutes ?? this.availableMinutes),
      energyLevel:
          clearEnergyLevel ? null : (energyLevel ?? this.energyLevel),
      workloadLevel:
          clearWorkloadLevel ? null : (workloadLevel ?? this.workloadLevel),
      dayType: clearDayType ? null : (dayType ?? this.dayType),
      shiftLabel: clearShiftLabel ? null : (shiftLabel ?? this.shiftLabel),
      challengePreference: clearChallengePreference
          ? null
          : (challengePreference ?? this.challengePreference),
      confidenceScore: clearConfidenceScore
          ? null
          : (confidenceScore ?? this.confidenceScore),
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyCheckIn &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
