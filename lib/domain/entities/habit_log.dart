/// Immutable habit log entry representing a single day's completion record.
class HabitLog {
  final String id;
  final String habitId;
  final DateTime date;
  final bool completed;
  final double? value;
  final bool skipped;
  final DateTime createdAt;

  const HabitLog({
    required this.id,
    required this.habitId,
    required this.date,
    required this.completed,
    this.value,
    this.skipped = false,
    required this.createdAt,
  });

  /// Normalised date with no time component.
  DateTime get normalisedDate => DateTime(date.year, date.month, date.day);

  HabitLog copyWith({
    String? id,
    String? habitId,
    DateTime? date,
    bool? completed,
    double? value,
    bool clearValue = false,
    bool? skipped,
    DateTime? createdAt,
  }) {
    return HabitLog(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      date: date ?? this.date,
      completed: completed ?? this.completed,
      value: clearValue ? null : (value ?? this.value),
      skipped: skipped ?? this.skipped,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'habitId': habitId,
      'date': date.toIso8601String(),
      'completed': completed,
      'value': value,
      'skipped': skipped,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HabitLog.fromJson(Map<String, dynamic> json) {
    return HabitLog(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      date: DateTime.parse(json['date'] as String),
      completed: json['completed'] as bool,
      value: (json['value'] as num?)?.toDouble(),
      skipped: json['skipped'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitLog && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
