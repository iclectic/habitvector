import 'package:flutter/material.dart';

/// Schedule type for a habit.
enum ScheduleType {
  daily,
  specificDays,
  customFrequency,
}

/// Goal type for a habit.
enum GoalType {
  tick,
  quantity,
}

/// Immutable habit entity.
class Habit {
  final String id;
  final String title;
  final String? description;
  final int colourValue;
  final int iconCodePoint;
  final String iconFontFamily;
  final ScheduleType scheduleType;
  final List<int> scheduledDays; // 1=Mon, 7=Sun (ISO)
  final int customFrequencyPerWeek;
  final GoalType goalType;
  final double? targetQuantity;
  final String? unit;
  final List<TimeOfDay> reminderTimes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;

  const Habit({
    required this.id,
    required this.title,
    this.description,
    required this.colourValue,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    required this.scheduleType,
    this.scheduledDays = const [],
    this.customFrequencyPerWeek = 1,
    required this.goalType,
    this.targetQuantity,
    this.unit,
    this.reminderTimes = const [],
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
  });

  Color get colour => Color(colourValue);

  IconData get icon => IconData(
        iconCodePoint,
        fontFamily: iconFontFamily,
      );

  bool isDueOn(DateTime date) {
    switch (scheduleType) {
      case ScheduleType.daily:
        return true;
      case ScheduleType.specificDays:
        return scheduledDays.contains(date.weekday);
      case ScheduleType.customFrequency:
        // For custom frequency, it's always "available" but tracked weekly
        return true;
    }
  }

  Habit copyWith({
    String? id,
    String? title,
    String? description,
    bool clearDescription = false,
    int? colourValue,
    int? iconCodePoint,
    String? iconFontFamily,
    ScheduleType? scheduleType,
    List<int>? scheduledDays,
    int? customFrequencyPerWeek,
    GoalType? goalType,
    double? targetQuantity,
    bool clearTargetQuantity = false,
    String? unit,
    bool clearUnit = false,
    List<TimeOfDay>? reminderTimes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? archived,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      colourValue: colourValue ?? this.colourValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      scheduleType: scheduleType ?? this.scheduleType,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      customFrequencyPerWeek:
          customFrequencyPerWeek ?? this.customFrequencyPerWeek,
      goalType: goalType ?? this.goalType,
      targetQuantity:
          clearTargetQuantity ? null : (targetQuantity ?? this.targetQuantity),
      unit: clearUnit ? null : (unit ?? this.unit),
      reminderTimes: reminderTimes ?? this.reminderTimes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'colourValue': colourValue,
      'iconCodePoint': iconCodePoint,
      'iconFontFamily': iconFontFamily,
      'scheduleType': scheduleType.index,
      'scheduledDays': scheduledDays,
      'customFrequencyPerWeek': customFrequencyPerWeek,
      'goalType': goalType.index,
      'targetQuantity': targetQuantity,
      'unit': unit,
      'reminderTimes':
          reminderTimes.map((t) => '${t.hour}:${t.minute}').toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'archived': archived,
    };
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      colourValue: json['colourValue'] as int,
      iconCodePoint: json['iconCodePoint'] as int,
      iconFontFamily: json['iconFontFamily'] as String? ?? 'MaterialIcons',
      scheduleType: ScheduleType.values[json['scheduleType'] as int],
      scheduledDays: (json['scheduledDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      customFrequencyPerWeek: json['customFrequencyPerWeek'] as int? ?? 1,
      goalType: GoalType.values[json['goalType'] as int],
      targetQuantity: (json['targetQuantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      reminderTimes: (json['reminderTimes'] as List<dynamic>?)?.map((t) {
            final parts = (t as String).split(':');
            return TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }).toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      archived: json['archived'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Habit && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
