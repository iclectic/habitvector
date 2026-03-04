import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/data/database/app_database.dart';
import 'package:habit_flow/data/repositories/drift_habit_repository.dart';
import 'package:habit_flow/data/repositories/drift_habit_log_repository.dart';
import 'package:habit_flow/domain/entities/habit.dart';
import 'package:habit_flow/domain/entities/habit_log.dart';

void main() {
  late AppDatabase db;
  late DriftHabitRepository habitRepo;
  late DriftHabitLogRepository logRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    habitRepo = DriftHabitRepository(db);
    logRepo = DriftHabitLogRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Habit _createHabit({
    String id = 'test-habit-1',
    String title = 'Test Habit',
    ScheduleType scheduleType = ScheduleType.daily,
    GoalType goalType = GoalType.tick,
    double? targetQuantity,
    String? unit,
  }) {
    return Habit(
      id: id,
      title: title,
      colourValue: 0xFF6366F1,
      iconCodePoint: Icons.fitness_center.codePoint,
      scheduleType: scheduleType,
      goalType: goalType,
      targetQuantity: targetQuantity,
      unit: unit,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
  }

  HabitLog _createLog({
    String id = 'test-log-1',
    String habitId = 'test-habit-1',
    required DateTime date,
    bool completed = true,
    double? value,
    bool skipped = false,
  }) {
    return HabitLog(
      id: id,
      habitId: habitId,
      date: date,
      completed: completed,
      value: value,
      skipped: skipped,
      createdAt: DateTime.now(),
    );
  }

  group('HabitRepository', () {
    test('should insert and retrieve a habit', () async {
      final habit = _createHabit();
      await habitRepo.insertHabit(habit);

      final retrieved = await habitRepo.getHabitById('test-habit-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'test-habit-1');
      expect(retrieved.title, 'Test Habit');
      expect(retrieved.scheduleType, ScheduleType.daily);
      expect(retrieved.goalType, GoalType.tick);
    });

    test('should return null for non-existent habit', () async {
      final result = await habitRepo.getHabitById('non-existent');
      expect(result, isNull);
    });

    test('should list all active habits', () async {
      await habitRepo.insertHabit(_createHabit(id: 'h1', title: 'Habit 1'));
      await habitRepo.insertHabit(_createHabit(id: 'h2', title: 'Habit 2'));
      await habitRepo.insertHabit(_createHabit(id: 'h3', title: 'Habit 3'));

      final habits = await habitRepo.getActiveHabits();
      expect(habits.length, 3);
    });

    test('should update a habit', () async {
      final habit = _createHabit();
      await habitRepo.insertHabit(habit);

      final updated = habit.copyWith(title: 'Updated Title');
      await habitRepo.updateHabit(updated);

      final retrieved = await habitRepo.getHabitById('test-habit-1');
      expect(retrieved!.title, 'Updated Title');
    });

    test('should archive and unarchive a habit', () async {
      final habit = _createHabit();
      await habitRepo.insertHabit(habit);

      await habitRepo.archiveHabit('test-habit-1');
      var retrieved = await habitRepo.getHabitById('test-habit-1');
      expect(retrieved!.archived, true);

      final active = await habitRepo.getActiveHabits();
      expect(active, isEmpty);

      final archived = await habitRepo.getArchivedHabits();
      expect(archived.length, 1);

      await habitRepo.unarchiveHabit('test-habit-1');
      retrieved = await habitRepo.getHabitById('test-habit-1');
      expect(retrieved!.archived, false);
    });

    test('should delete a habit', () async {
      final habit = _createHabit();
      await habitRepo.insertHabit(habit);

      await habitRepo.deleteHabit('test-habit-1');
      final result = await habitRepo.getHabitById('test-habit-1');
      expect(result, isNull);
    });

    test('should watch active habits stream', () async {
      final stream = habitRepo.watchActiveHabits();

      await habitRepo.insertHabit(_createHabit(id: 'h1', title: 'Habit 1'));

      await expectLater(
        stream,
        emits(predicate<List<Habit>>((habits) => habits.length == 1)),
      );
    });
  });

  group('HabitLogRepository', () {
    setUp(() async {
      // Insert a habit first (foreign key)
      await habitRepo.insertHabit(_createHabit());
    });

    test('should insert and retrieve a log', () async {
      final log = _createLog(date: DateTime(2024, 3, 15));
      await logRepo.insertLog(log);

      final logs = await logRepo.getLogsForHabit('test-habit-1');
      expect(logs.length, 1);
      expect(logs.first.completed, true);
    });

    test('should get log for specific date', () async {
      await logRepo.insertLog(
          _createLog(id: 'l1', date: DateTime(2024, 3, 15)));
      await logRepo.insertLog(
          _createLog(id: 'l2', date: DateTime(2024, 3, 16)));

      final log = await logRepo.getLogForHabitOnDate(
          'test-habit-1', DateTime(2024, 3, 15));
      expect(log, isNotNull);
      expect(log!.id, 'l1');
    });

    test('should get logs in date range', () async {
      await logRepo.insertLog(
          _createLog(id: 'l1', date: DateTime(2024, 3, 10)));
      await logRepo.insertLog(
          _createLog(id: 'l2', date: DateTime(2024, 3, 15)));
      await logRepo.insertLog(
          _createLog(id: 'l3', date: DateTime(2024, 3, 20)));

      final logs = await logRepo.getLogsForHabitInRange(
        'test-habit-1',
        DateTime(2024, 3, 12),
        DateTime(2024, 3, 18),
      );
      expect(logs.length, 1);
      expect(logs.first.id, 'l2');
    });

    test('should update a log', () async {
      final log = _createLog(date: DateTime(2024, 3, 15), completed: false);
      await logRepo.insertLog(log);

      final updated = log.copyWith(completed: true);
      await logRepo.updateLog(updated);

      final retrieved = await logRepo.getLogForHabitOnDate(
          'test-habit-1', DateTime(2024, 3, 15));
      expect(retrieved!.completed, true);
    });

    test('should delete a log', () async {
      await logRepo.insertLog(
          _createLog(id: 'l1', date: DateTime(2024, 3, 15)));

      await logRepo.deleteLog('l1');
      final logs = await logRepo.getLogsForHabit('test-habit-1');
      expect(logs, isEmpty);
    });

    test('should delete all logs for a habit', () async {
      await logRepo.insertLog(
          _createLog(id: 'l1', date: DateTime(2024, 3, 15)));
      await logRepo.insertLog(
          _createLog(id: 'l2', date: DateTime(2024, 3, 16)));
      await logRepo.insertLog(
          _createLog(id: 'l3', date: DateTime(2024, 3, 17)));

      await logRepo.deleteLogsForHabit('test-habit-1');
      final logs = await logRepo.getLogsForHabit('test-habit-1');
      expect(logs, isEmpty);
    });

    test('should get all logs for a specific date', () async {
      // Insert second habit
      await habitRepo.insertHabit(
          _createHabit(id: 'test-habit-2', title: 'Habit 2'));

      await logRepo.insertLog(_createLog(
        id: 'l1',
        habitId: 'test-habit-1',
        date: DateTime(2024, 3, 15),
      ));
      await logRepo.insertLog(_createLog(
        id: 'l2',
        habitId: 'test-habit-2',
        date: DateTime(2024, 3, 15),
      ));
      await logRepo.insertLog(_createLog(
        id: 'l3',
        habitId: 'test-habit-1',
        date: DateTime(2024, 3, 16),
      ));

      final logs = await logRepo.getLogsForDate(DateTime(2024, 3, 15));
      expect(logs.length, 2);
    });

    test('should handle quantity logs correctly', () async {
      final log = _createLog(
        date: DateTime(2024, 3, 15),
        completed: true,
        value: 8.5,
      );
      await logRepo.insertLog(log);

      final retrieved = await logRepo.getLogForHabitOnDate(
          'test-habit-1', DateTime(2024, 3, 15));
      expect(retrieved!.value, 8.5);
      expect(retrieved.completed, true);
    });

    test('should handle skipped logs', () async {
      final log = _createLog(
        date: DateTime(2024, 3, 15),
        completed: false,
        skipped: true,
      );
      await logRepo.insertLog(log);

      final retrieved = await logRepo.getLogForHabitOnDate(
          'test-habit-1', DateTime(2024, 3, 15));
      expect(retrieved!.skipped, true);
      expect(retrieved.completed, false);
    });
  });
}
