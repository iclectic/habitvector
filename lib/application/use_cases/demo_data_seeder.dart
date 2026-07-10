import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/daily_check_in.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_experiment.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/entities/work_shift.dart';
import '../../domain/repositories/context_repository.dart';
import '../../domain/repositories/experiment_repository.dart';
import '../../domain/repositories/habit_log_repository.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../domain/repositories/shift_repository.dart';

/// Seeds the app with realistic demo data for portfolio demonstrations.
///
/// The seeder creates a plausible 30-day history for a shift worker named
/// "Alex" who is trying to build three habits: morning exercise, evening
/// reading, and a hydration goal. It includes:
///
/// - 3 habits (tick × 2, quantity × 1)
/// - 30 days of habit logs with realistic completion patterns
/// - 30 daily check-ins with varying energy and workload levels
/// - 6 work shifts (night-shift pattern, 3 on / 3 off)
/// - 1 completed experiment comparing morning vs evening exercise timing
/// - 1 active experiment comparing 5-min vs 20-min reading sessions
///
/// Idempotent: does nothing if demo habits already exist.
class DemoDataSeeder {
  final HabitRepository _habitRepo;
  final HabitLogRepository _logRepo;
  final ContextRepository _contextRepo;
  final ShiftRepository _shiftRepo;
  final ExperimentRepository _experimentRepo;
  final Uuid _uuid;

  DemoDataSeeder({
    required HabitRepository habitRepo,
    required HabitLogRepository logRepo,
    required ContextRepository contextRepo,
    required ShiftRepository shiftRepo,
    required ExperimentRepository experimentRepo,
    Uuid? uuid,
  })  : _habitRepo = habitRepo,
        _logRepo = logRepo,
        _contextRepo = contextRepo,
        _shiftRepo = shiftRepo,
        _experimentRepo = experimentRepo,
        _uuid = uuid ?? const Uuid();

  static const String _demoTag = '__demo__';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns true if demo data has already been seeded.
  Future<bool> isSeeded() async {
    final habits = await _habitRepo.getAllHabits();
    return habits.any((h) => h.title.startsWith(_demoTag));
  }

  /// Seed demo data. Safe to call multiple times — checks [isSeeded] first.
  Future<void> seed({DateTime? referenceDate}) async {
    if (await isSeeded()) return;

    final today = _normalise(referenceDate ?? DateTime.now());
    final rng = Random(42); // Deterministic for reproducibility

    // Habits
    final exerciseHabit = _exerciseHabit();
    final readingHabit = _readingHabit();
    final hydrationHabit = _hydrationHabit();

    await _habitRepo.insertHabit(exerciseHabit);
    await _habitRepo.insertHabit(readingHabit);
    await _habitRepo.insertHabit(hydrationHabit);

    // Shifts (3-on / 3-off night pattern, rolling from day -30)
    final shifts = _buildShifts(today);
    for (final s in shifts) {
      await _shiftRepo.insertShift(s);
    }

    // Check-ins + logs for past 30 days
    for (int i = 29; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final shiftOnDay = shifts.where((s) => _normalise(s.startTime) == date).firstOrNull;
      final isNightShift = shiftOnDay != null;

      final checkIn = _buildCheckIn(date, isNightShift, rng);
      await _contextRepo.insertCheckIn(checkIn);

      // Exercise: harder on night shifts, easier on rest days
      await _logRepo.insertLog(_exerciseLog(
        exerciseHabit.id,
        date,
        isNightShift: isNightShift,
        energyLow: checkIn.energyLevel == EnergyLevel.low ||
            checkIn.energyLevel == EnergyLevel.veryLow,
        rng: rng,
      ));

      // Reading: fairly consistent, drops slightly on heavy workload days
      await _logRepo.insertLog(_readingLog(
        readingHabit.id,
        date,
        heavyWorkload: checkIn.workloadLevel == WorkloadLevel.heavy ||
            checkIn.workloadLevel == WorkloadLevel.overwhelming,
        rng: rng,
      ));

      // Hydration: quantity habit, 0–3000 ml logged
      await _logRepo.insertLog(_hydrationLog(
        hydrationHabit.id,
        date,
        isNightShift: isNightShift,
        rng: rng,
      ));
    }

    // Experiments
    await _seedCompletedExperiment(exerciseHabit.id, today);
    await _seedActiveExperiment(readingHabit.id, today);
  }

  /// Remove all demo data (habits + cascaded logs, check-ins, shifts, experiments).
  Future<void> clear() async {
    final habits = await _habitRepo.getAllHabits();
    for (final h in habits.where((h) => h.title.startsWith(_demoTag))) {
      await _habitRepo.deleteHabit(h.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Habit builders
  // ---------------------------------------------------------------------------

  Habit _exerciseHabit() => Habit(
        id: _uuid.v4(),
        title: '${_demoTag}Morning Exercise',
        colourValue: 0xFF6366F1,
        iconCodePoint: Icons.directions_run_rounded.codePoint,
        scheduleType: ScheduleType.daily,
        goalType: GoalType.tick,
        description: 'Min: 5-min walk · Std: 20-min jog · Stretch: 45-min run',
        createdAt: DateTime.now().subtract(const Duration(days: 35)),
        updatedAt: DateTime.now(),
      );

  Habit _readingHabit() => Habit(
        id: _uuid.v4(),
        title: '${_demoTag}Evening Reading',
        colourValue: 0xFF10B981,
        iconCodePoint: Icons.menu_book_rounded.codePoint,
        scheduleType: ScheduleType.daily,
        goalType: GoalType.tick,
        description: 'Min: 5 min · Std: 20 min · Stretch: 45 min',
        createdAt: DateTime.now().subtract(const Duration(days: 35)),
        updatedAt: DateTime.now(),
      );

  Habit _hydrationHabit() => Habit(
        id: _uuid.v4(),
        title: '${_demoTag}Hydration',
        colourValue: 0xFF3B82F6,
        iconCodePoint: Icons.water_drop_rounded.codePoint,
        scheduleType: ScheduleType.daily,
        goalType: GoalType.quantity,
        targetQuantity: 2500,
        unit: 'ml',
        createdAt: DateTime.now().subtract(const Duration(days: 35)),
        updatedAt: DateTime.now(),
      );

  // ---------------------------------------------------------------------------
  // Shift builders
  // ---------------------------------------------------------------------------

  List<WorkShift> _buildShifts(DateTime today) {
    final shifts = <WorkShift>[];
    // 3-on (night) / 3-off rolling pattern, starting 30 days ago
    for (int i = 0; i < 10; i++) {
      final startDay = today.subtract(Duration(days: 29 - (i * 6)));
      // Each cycle: 3 night shifts, then 3 off
      for (int d = 0; d < 3; d++) {
        final shiftDate = startDay.add(Duration(days: d));
        shifts.add(WorkShift(
          id: _uuid.v4(),
          label: 'Night shift',
          startTime: DateTime(shiftDate.year, shiftDate.month, shiftDate.day, 22, 0),
          endTime: DateTime(shiftDate.year, shiftDate.month, shiftDate.day + 1, 7, 0),
          isOvernight: true,
          createdAt: today.subtract(const Duration(days: 35)),
          updatedAt: today,
        ));
      }
    }
    return shifts;
  }

  // ---------------------------------------------------------------------------
  // Check-in builder
  // ---------------------------------------------------------------------------

  DailyCheckIn _buildCheckIn(DateTime date, bool isNightShift, Random rng) {
    final energyOptions = EnergyLevel.values;
    final workloadOptions = WorkloadLevel.values;

    // Night shifts → lower energy, higher workload
    final energyIndex = isNightShift
        ? rng.nextInt(3) // veryLow, low, moderate
        : rng.nextInt(EnergyLevel.values.length);
    final workloadIndex = isNightShift
        ? 1 + rng.nextInt(3) // moderate, heavy, overwhelming
        : rng.nextInt(WorkloadLevel.values.length);

    return DailyCheckIn(
      id: _uuid.v4(),
      date: date,
      energyLevel: energyOptions[energyIndex.clamp(0, energyOptions.length - 1)],
      workloadLevel: workloadOptions[workloadIndex.clamp(0, workloadOptions.length - 1)],
      dayType: isNightShift ? DayType.shiftDay : _dayType(date),
      createdAt: date,
    );
  }

  DayType _dayType(DateTime date) {
    if (date.weekday >= 6) return DayType.restDay;
    return DayType.workday;
  }

  // ---------------------------------------------------------------------------
  // Log builders
  // ---------------------------------------------------------------------------

  HabitLog _exerciseLog(
    String habitId,
    DateTime date, {
    required bool isNightShift,
    required bool energyLow,
    required Random rng,
  }) {
    // Night shift or low energy → 35% completion, else 75%
    final completionChance = (isNightShift || energyLow) ? 0.35 : 0.75;
    final roll = rng.nextDouble();
    final completed = roll < completionChance;
    final skipped = !completed && roll < completionChance + 0.20;

    return HabitLog(
      id: _uuid.v4(),
      habitId: habitId,
      date: date,
      completed: completed,
      skipped: skipped && !completed,
      createdAt: date,
    );
  }

  HabitLog _readingLog(
    String habitId,
    DateTime date, {
    required bool heavyWorkload,
    required Random rng,
  }) {
    final completionChance = heavyWorkload ? 0.55 : 0.80;
    final completed = rng.nextDouble() < completionChance;

    return HabitLog(
      id: _uuid.v4(),
      habitId: habitId,
      date: date,
      completed: completed,
      skipped: false,
      createdAt: date,
    );
  }

  HabitLog _hydrationLog(
    String habitId,
    DateTime date, {
    required bool isNightShift,
    required Random rng,
  }) {
    // Night shift: 1200–2000 ml; rest day: 1800–3000 ml
    final base = isNightShift ? 1200.0 : 1800.0;
    final range = isNightShift ? 800.0 : 1200.0;
    final value = base + rng.nextDouble() * range;
    final target = 2500.0;
    final completed = value >= target;

    return HabitLog(
      id: _uuid.v4(),
      habitId: habitId,
      date: date,
      completed: completed,
      skipped: false,
      value: double.parse(value.toStringAsFixed(0)),
      createdAt: date,
    );
  }

  // ---------------------------------------------------------------------------
  // Experiment builders
  // ---------------------------------------------------------------------------

  Future<void> _seedCompletedExperiment(
      String exerciseHabitId, DateTime today) async {
    final expId = _uuid.v4();
    final startDate = today.subtract(const Duration(days: 28));
    final endDate = today.subtract(const Duration(days: 1));

    final experiment = HabitExperiment(
      id: expId,
      habitId: exerciseHabitId,
      title: '${_demoTag}Morning vs Evening Exercise',
      hypothesis:
          'Exercising in the morning (before my shift) will have a higher completion rate than evening.',
      primaryOutcome: 'daily completion rate',
      interventionA: 'Morning (6 am)',
      interventionB: 'Evening (7 pm)',
      assignmentStrategy: AssignmentStrategy.alternating,
      durationDays: 28,
      minimumObservations: 20,
      startDate: startDate,
      endDate: endDate,
      status: ExperimentStatus.completed,
      resultSummary:
          'In this 28-observation experiment, "Morning (6 am)" was associated '
          'with a noticeable difference in completion (71% vs 50%, a 21% gap). '
          'This is an observational pattern — other factors may have contributed. '
          'Consider whether this aligns with your experience before adopting it '
          'as your default approach.',
      createdAt: startDate,
      updatedAt: endDate,
    );
    await _experimentRepo.insertExperiment(experiment);

    // Seed 28 observations: alternating A/B
    for (int i = 0; i < 28; i++) {
      final obsDate = startDate.add(Duration(days: i));
      final isA = i.isEven;
      // Morning (A) → 71% completion; Evening (B) → 50%
      final completed = isA ? (i % 7 != 0) : (i % 2 == 0);

      await _experimentRepo.insertObservation(ExperimentObservation(
        id: _uuid.v4(),
        experimentId: expId,
        habitId: exerciseHabitId,
        date: obsDate,
        assignment:
            isA ? InterventionAssignment.a : InterventionAssignment.b,
        completed: completed,
        createdAt: obsDate,
      ));
    }
  }

  Future<void> _seedActiveExperiment(
      String readingHabitId, DateTime today) async {
    final expId = _uuid.v4();
    final startDate = today.subtract(const Duration(days: 13));

    final experiment = HabitExperiment(
      id: expId,
      habitId: readingHabitId,
      title: '${_demoTag}5-min vs 20-min Reading Session',
      hypothesis:
          'A shorter 5-minute minimum will lead to higher completion on busy days without reducing overall engagement.',
      primaryOutcome: 'daily completion rate',
      interventionA: '5-minute session',
      interventionB: '20-minute session',
      assignmentStrategy: AssignmentStrategy.alternating,
      durationDays: 28,
      minimumObservations: 20,
      startDate: startDate,
      status: ExperimentStatus.active,
      createdAt: startDate,
      updatedAt: today,
    );
    await _experimentRepo.insertExperiment(experiment);

    // Seed 14 observations so far
    final rng = Random(7);
    for (int i = 0; i < 14; i++) {
      final obsDate = startDate.add(Duration(days: i));
      final isA = i.isEven; // A = 5-min
      final completed = isA ? rng.nextDouble() < 0.85 : rng.nextDouble() < 0.65;

      await _experimentRepo.insertObservation(ExperimentObservation(
        id: _uuid.v4(),
        experimentId: expId,
        habitId: readingHabitId,
        date: obsDate,
        assignment:
            isA ? InterventionAssignment.a : InterventionAssignment.b,
        completed: completed,
        createdAt: obsDate,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  DateTime _normalise(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
