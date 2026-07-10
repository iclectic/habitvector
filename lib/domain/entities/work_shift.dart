/// Recurrence pattern for a shift.
enum ShiftRecurrence {
  oneOff,
  weekly,
  fortnightly,
  custom,
}

/// A user-entered shift entry.
///
/// Users enter shifts manually. Calendar import requires explicit permission
/// and is handled separately. Precise location is never collected.
class WorkShift {
  final String id;
  final String label; // e.g. "Day shift", "Night shift", "Study day"
  final DateTime startTime;
  final DateTime endTime;
  final bool isOvernight;
  final ShiftRecurrence recurrence;
  final List<int> recurrenceWeekdays; // ISO weekdays 1=Mon if weekly
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;

  const WorkShift({
    required this.id,
    required this.label,
    required this.startTime,
    required this.endTime,
    this.isOvernight = false,
    this.recurrence = ShiftRecurrence.oneOff,
    this.recurrenceWeekdays = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
  });

  /// Duration of this shift.
  Duration get duration => endTime.difference(startTime);

  /// Normalised date of the shift start.
  DateTime get shiftDate =>
      DateTime(startTime.year, startTime.month, startTime.day);

  WorkShift copyWith({
    String? id,
    String? label,
    DateTime? startTime,
    DateTime? endTime,
    bool? isOvernight,
    ShiftRecurrence? recurrence,
    List<int>? recurrenceWeekdays,
    String? notes,
    bool clearNotes = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? archived,
  }) {
    return WorkShift(
      id: id ?? this.id,
      label: label ?? this.label,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isOvernight: isOvernight ?? this.isOvernight,
      recurrence: recurrence ?? this.recurrence,
      recurrenceWeekdays: recurrenceWeekdays ?? this.recurrenceWeekdays,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archived: archived ?? this.archived,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkShift &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
