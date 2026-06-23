import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/application/use_cases/export_import_use_cases.dart';
import 'package:habit_flow/data/database/app_database.dart';
import 'package:habit_flow/data/repositories/drift_habit_log_repository.dart';
import 'package:habit_flow/data/repositories/drift_habit_repository.dart';
import 'package:habit_flow/domain/entities/habit.dart';
import 'package:habit_flow/domain/entities/habit_log.dart';

void main() {
  late AppDatabase db;
  late ExportImportUseCases useCases;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    useCases = ExportImportUseCases(
      DriftHabitRepository(db),
      DriftHabitLogRepository(db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Habit habit({String id = 'habit-1'}) {
    return Habit(
      id: id,
      title: 'Drink Water',
      colourValue: 0xFF06B6D4,
      iconCodePoint: Icons.water_drop.codePoint,
      scheduleType: ScheduleType.daily,
      goalType: GoalType.quantity,
      targetQuantity: 8,
      unit: 'glasses',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  HabitLog log({
    String id = 'log-1',
    String habitId = 'habit-1',
    DateTime? date,
  }) {
    return HabitLog(
      id: id,
      habitId: habitId,
      date: date ?? DateTime(2026, 1, 2),
      completed: true,
      value: 8,
      createdAt: DateTime(2026, 1, 2),
    );
  }

  String backupJson({
    String version = ExportImportUseCases.supportedVersion,
    List<Habit>? habits,
    List<HabitLog>? logs,
  }) {
    return jsonEncode(
      ExportData(
        version: version,
        exportedAt: DateTime(2026, 1, 3),
        habits: habits ?? [habit()],
        logs: logs ?? [log()],
      ).toJson(),
    );
  }

  test('rejects unsupported backup versions', () {
    final validation = useCases.validateJson(backupJson(version: '2.0.0'));

    expect(validation.isValid, false);
    expect(
      validation.errors,
      contains(contains('Unsupported backup version')),
    );
  });

  test('rejects duplicate logs for the same habit and date', () {
    final validation = useCases.validateJson(
      backupJson(
        logs: [
          log(id: 'log-1'),
          log(id: 'log-2'),
        ],
      ),
    );

    expect(validation.isValid, false);
    expect(
      validation.errors,
      contains(contains('Multiple logs found for habit habit-1')),
    );
  });

  test('imports valid backup data', () async {
    await useCases.importFromJson(backupJson());

    final exported = await useCases.exportToJson();
    final data = ExportData.fromJson(jsonDecode(exported));

    expect(data.habits.single.title, 'Drink Water');
    expect(data.logs.single.habitId, 'habit-1');
  });
}
