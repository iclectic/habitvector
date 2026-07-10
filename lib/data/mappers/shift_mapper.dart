import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/entities/work_shift.dart';
import '../database/app_database.dart';

/// Maps between domain [WorkShift] entity and Drift [WorkShiftRow].
class ShiftMapper {
  static WorkShift toDomain(WorkShiftRow db) {
    final weekdays = (jsonDecode(db.recurrenceWeekdays) as List<dynamic>)
        .map((e) => e as int)
        .toList();
    return WorkShift(
      id: db.id,
      label: db.label,
      startTime: db.startTime,
      endTime: db.endTime,
      isOvernight: db.isOvernight,
      recurrence: ShiftRecurrence.values[db.recurrence],
      recurrenceWeekdays: weekdays,
      notes: db.notes,
      createdAt: db.createdAt,
      updatedAt: db.updatedAt,
      archived: db.archived,
    );
  }

  static WorkShiftsCompanion toCompanion(WorkShift s) {
    return WorkShiftsCompanion.insert(
      id: s.id,
      label: s.label,
      startTime: s.startTime,
      endTime: s.endTime,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    ).copyWith(
      isOvernight: Value(s.isOvernight),
      recurrence: Value(s.recurrence.index),
      recurrenceWeekdays: Value(jsonEncode(s.recurrenceWeekdays)),
      notes: s.notes != null ? Value(s.notes) : const Value(null),
      archived: Value(s.archived),
    );
  }
}
