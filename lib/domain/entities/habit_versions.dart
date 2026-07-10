/// Which version of a habit was attempted or completed.
enum HabitVersionLevel {
  minimum,
  standard,
  stretch,
}

/// Optional three-level version definitions for a habit.
///
/// Every habit has a standard version (the existing definition).
/// Minimum and stretch are optional additions that let the user
/// adapt the habit to different context conditions.
///
/// Example for "Walking":
///   minimum: 5-minute walk
///   standard: 20-minute walk
///   stretch: 40-minute walk
class HabitVersions {
  final String id;
  final String habitId;
  final String? minimumDescription;
  final int? minimumDurationMinutes;
  final String? standardDescription;
  final int? standardDurationMinutes;
  final String? stretchDescription;
  final int? stretchDurationMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HabitVersions({
    required this.id,
    required this.habitId,
    this.minimumDescription,
    this.minimumDurationMinutes,
    this.standardDescription,
    this.standardDurationMinutes,
    this.stretchDescription,
    this.stretchDurationMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasMinimum =>
      minimumDescription != null || minimumDurationMinutes != null;

  bool get hasStretch =>
      stretchDescription != null || stretchDurationMinutes != null;

  HabitVersions copyWith({
    String? id,
    String? habitId,
    String? minimumDescription,
    bool clearMinimumDescription = false,
    int? minimumDurationMinutes,
    bool clearMinimumDuration = false,
    String? standardDescription,
    bool clearStandardDescription = false,
    int? standardDurationMinutes,
    bool clearStandardDuration = false,
    String? stretchDescription,
    bool clearStretchDescription = false,
    int? stretchDurationMinutes,
    bool clearStretchDuration = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitVersions(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      minimumDescription: clearMinimumDescription
          ? null
          : (minimumDescription ?? this.minimumDescription),
      minimumDurationMinutes: clearMinimumDuration
          ? null
          : (minimumDurationMinutes ?? this.minimumDurationMinutes),
      standardDescription: clearStandardDescription
          ? null
          : (standardDescription ?? this.standardDescription),
      standardDurationMinutes: clearStandardDuration
          ? null
          : (standardDurationMinutes ?? this.standardDurationMinutes),
      stretchDescription: clearStretchDescription
          ? null
          : (stretchDescription ?? this.stretchDescription),
      stretchDurationMinutes: clearStretchDuration
          ? null
          : (stretchDurationMinutes ?? this.stretchDurationMinutes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitVersions &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
