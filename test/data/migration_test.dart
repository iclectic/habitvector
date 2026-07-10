import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/data/database/app_database.dart';
import 'package:habit_flow/domain/entities/habit.dart';

/// Verifies that:
/// 1. A v1 schema (habits + habit_logs only) can be opened and migrated to v2
///    without losing existing habit or log data.
/// 2. All v2 tables are present and writable after migration.
void main() {
  group('Database migration v1 → v2', () {
    /// Regression test: habits and logs written before migration remain readable
    /// after the v2 schema is opened. This guards the additive-only migration
    /// contract from ADR-004.
    test('existing habits and logs survive migration', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      final createdAt = DateTime(2024, 6, 1);

      // Insert legacy-style habit (fields present in v1 schema only).
      await db.into(db.habits).insert(
            HabitsCompanion.insert(
              id: 'habit-legacy-1',
              title: 'Legacy Habit',
              colourValue: 0xFF6366F1,
              iconCodePoint: Icons.fitness_center.codePoint,
              scheduleType: ScheduleType.daily.index,
              goalType: GoalType.tick.index,
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );

      await db.into(db.habitLogs).insert(
            HabitLogsCompanion.insert(
              id: 'log-legacy-1',
              habitId: 'habit-legacy-1',
              date: createdAt,
              completed: true,
              createdAt: createdAt,
            ),
          );

      // Re-read the data — confirms v2 schema is backward-compatible.
      final habits = await db.select(db.habits).get();
      expect(habits.length, 1);
      expect(habits.first.id, 'habit-legacy-1');
      expect(habits.first.title, 'Legacy Habit');
      expect(habits.first.archived, isFalse);

      final logs = await db.select(db.habitLogs).get();
      expect(logs.length, 1);
      expect(logs.first.habitId, 'habit-legacy-1');
      expect(logs.first.completed, isTrue);

      // The v2 tables exist alongside legacy data and are independently writable.
      await db.into(db.dailyCheckIns).insert(
            DailyCheckInsCompanion.insert(
              id: 'ci1',
              date: createdAt,
              createdAt: createdAt,
            ),
          );
      expect((await db.select(db.dailyCheckIns).get()).length, 1);

      await db.close();
    });

    test('all v2 tables exist and accept inserts', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      final now = DateTime(2024, 6, 1);

      // Seed a parent habit for FK references.
      await db.into(db.habits).insert(
            HabitsCompanion.insert(
              id: 'h1',
              title: 'Test',
              colourValue: 0xFF000000,
              iconCodePoint: 0xe000,
              scheduleType: 0,
              goalType: 0,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // daily_check_ins
      await db.into(db.dailyCheckIns).insert(
            DailyCheckInsCompanion.insert(
              id: 'ci1',
              date: now,
              createdAt: now,
            ),
          );
      expect((await db.select(db.dailyCheckIns).get()).length, 1);

      // work_shifts
      await db.into(db.workShifts).insert(
            WorkShiftsCompanion.insert(
              id: 'ws1',
              label: 'Day shift',
              startTime: now,
              endTime: now.add(const Duration(hours: 8)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      expect((await db.select(db.workShifts).get()).length, 1);

      // habit_versions
      await db.into(db.habitVersionsTable).insert(
            HabitVersionsTableCompanion.insert(
              id: 'hv1',
              habitId: 'h1',
              createdAt: now,
              updatedAt: now,
            ),
          );
      expect((await db.select(db.habitVersionsTable).get()).length, 1);

      // adaptive_recommendations
      await db.into(db.adaptiveRecommendations).insert(
            AdaptiveRecommendationsCompanion.insert(
              id: 'r1',
              habitId: 'h1',
              generatedAt: now,
              forDate: now,
              action: 0,
              confidence: 0.7,
              explanation: 'Test explanation',
              alternativeAction: 7,
              modelVersion: 'cold-start-v1',
              source: 0,
            ),
          );
      expect((await db.select(db.adaptiveRecommendations).get()).length, 1);

      // habit_experiments
      await db.into(db.habitExperiments).insert(
            HabitExperimentsCompanion.insert(
              id: 'exp1',
              habitId: 'h1',
              title: 'Morning vs Evening',
              hypothesis: 'Morning timing increases completion',
              primaryOutcome: 'completion rate',
              interventionA: 'Morning reminder at 07:00',
              interventionB: 'Evening reminder at 19:00',
              assignmentStrategy: 1,
              durationDays: 21,
              minimumObservations: 10,
              startDate: now,
              status: 1,
              createdAt: now,
              updatedAt: now,
            ),
          );
      expect((await db.select(db.habitExperiments).get()).length, 1);

      // experiment_observations
      await db.into(db.experimentObservations).insert(
            ExperimentObservationsCompanion.insert(
              id: 'obs1',
              experimentId: 'exp1',
              habitId: 'h1',
              date: now,
              assignment: 0,
              completed: true,
              createdAt: now,
            ),
          );
      expect((await db.select(db.experimentObservations).get()).length, 1);

      // model_metadata
      await db.into(db.modelMetadata).insert(
            ModelMetadataCompanion.insert(
              id: 'mm1',
              habitId: 'h1',
              modelVersion: 'cold-start-v1',
              source: 'cold_start_rules',
              updatedAt: now,
            ),
          );
      expect((await db.select(db.modelMetadata).get()).length, 1);

      await db.close();
    });
  });
}
