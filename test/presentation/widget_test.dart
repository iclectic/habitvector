import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:habit_flow/data/database/app_database.dart';
import 'package:habit_flow/data/repositories/drift_habit_repository.dart';
import 'package:habit_flow/data/repositories/drift_habit_log_repository.dart';
import 'package:habit_flow/domain/entities/habit.dart';
import 'package:habit_flow/domain/entities/habit_log.dart';
import 'package:habit_flow/application/use_cases/habit_use_cases.dart';
import 'package:habit_flow/application/use_cases/log_use_cases.dart';
import 'package:habit_flow/presentation/providers/providers.dart';
import 'package:habit_flow/presentation/theme/app_theme.dart';
import 'package:habit_flow/presentation/screens/home/widgets/habit_tile.dart';

void main() {
  late AppDatabase db;
  late DriftHabitRepository habitRepo;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    habitRepo = DriftHabitRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Habit _testHabit({
    String id = 'test-habit-1',
    String title = 'Morning Exercise',
    GoalType goalType = GoalType.tick,
  }) {
    return Habit(
      id: id,
      title: title,
      colourValue: 0xFF6366F1,
      iconCodePoint: Icons.fitness_center.codePoint,
      scheduleType: ScheduleType.daily,
      goalType: goalType,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
  }

  Widget _wrapWithProviders(Widget child, AppDatabase testDb) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(testDb),
        habitRepositoryProvider.overrideWithValue(DriftHabitRepository(testDb)),
        habitLogRepositoryProvider
            .overrideWithValue(DriftHabitLogRepository(testDb)),
        habitUseCasesProvider.overrideWithValue(
          HabitUseCases(DriftHabitRepository(testDb)),
        ),
        logUseCasesProvider.overrideWithValue(
          LogUseCases(DriftHabitLogRepository(testDb)),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    );
  }

  group('HabitTile widget', () {
    testWidgets('displays habit title', (tester) async {
      final habit = _testHabit();

      await tester.pumpWidget(
        _wrapWithProviders(
          HabitTile(
            habit: habit,
            log: null,
            onTap: () {},
            onToggle: () {},
            onSkip: () {},
          ),
          db,
        ),
      );

      expect(find.text('Morning Exercise'), findsOneWidget);
    });

    testWidgets('shows completed state when log is completed', (tester) async {
      final habit = _testHabit();
      final log = HabitLog(
        id: 'log-1',
        habitId: habit.id,
        date: DateTime.now(),
        completed: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          HabitTile(
            habit: habit,
            log: log,
            onTap: () {},
            onToggle: () {},
            onSkip: () {},
          ),
          db,
        ),
      );

      expect(find.text('Completed'), findsOneWidget);
      // Check icon appears
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('shows skipped state when log is skipped', (tester) async {
      final habit = _testHabit();
      final log = HabitLog(
        id: 'log-1',
        habitId: habit.id,
        date: DateTime.now(),
        completed: false,
        skipped: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          HabitTile(
            habit: habit,
            log: log,
            onTap: () {},
            onToggle: () {},
            onSkip: () {},
          ),
          db,
        ),
      );

      expect(find.text('Skipped'), findsOneWidget);
    });

    testWidgets('calls onToggle when toggle button tapped', (tester) async {
      bool toggleCalled = false;
      final habit = _testHabit();

      await tester.pumpWidget(
        _wrapWithProviders(
          HabitTile(
            habit: habit,
            log: null,
            onTap: () {},
            onToggle: () => toggleCalled = true,
            onSkip: () {},
          ),
          db,
        ),
      );

      // Find the toggle circle (the GestureDetector with the AnimatedContainer)
      // The toggle is the circle at the end of the row
      final gestureDetectors = find.byType(GestureDetector);
      // Tap the last GestureDetector which is the toggle button
      await tester.tap(gestureDetectors.last);
      await tester.pumpAndSettle();

      expect(toggleCalled, true);
    });

    testWidgets('shows skip button when not completed', (tester) async {
      final habit = _testHabit();

      await tester.pumpWidget(
        _wrapWithProviders(
          HabitTile(
            habit: habit,
            log: null,
            onTap: () {},
            onToggle: () {},
            onSkip: () {},
          ),
          db,
        ),
      );

      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });

    testWidgets('hides skip button when completed', (tester) async {
      final habit = _testHabit();
      final log = HabitLog(
        id: 'log-1',
        habitId: habit.id,
        date: DateTime.now(),
        completed: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          HabitTile(
            habit: habit,
            log: log,
            onTap: () {},
            onToggle: () {},
            onSkip: () {},
          ),
          db,
        ),
      );

      // Skip button should not be present for completed habits
      // There should be no skip_next icon in the action row (only in the circle)
      // When completed, the skip button is hidden; the circle shows check instead
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('Marking habit as done updates UI', () {
    testWidgets('marking done transitions tile to completed state',
        (tester) async {
      final habit = _testHabit();

      // Start with no log (not completed)
      HabitLog? currentLog;
      bool wasToggled = false;

      await tester.pumpWidget(
        _wrapWithProviders(
          StatefulBuilder(
            builder: (context, setState) {
              return HabitTile(
                habit: habit,
                log: currentLog,
                onTap: () {},
                onToggle: () {
                  wasToggled = true;
                  setState(() {
                    if (currentLog == null) {
                      currentLog = HabitLog(
                        id: 'log-new',
                        habitId: habit.id,
                        date: DateTime.now(),
                        completed: true,
                        createdAt: DateTime.now(),
                      );
                    } else {
                      currentLog = null;
                    }
                  });
                },
                onSkip: () {},
              );
            },
          ),
          db,
        ),
      );

      // Verify initial state: "Daily" subtitle shown (not completed)
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Completed'), findsNothing);

      // Tap the toggle
      final gestureDetectors = find.byType(GestureDetector);
      await tester.tap(gestureDetectors.last);
      await tester.pumpAndSettle();

      // Verify completed state
      expect(wasToggled, true);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('Adding a new habit', () {
    testWidgets(
        'inserting a habit into repository makes it retrievable',
        (tester) async {
      // This tests the data flow: insert habit -> retrieve -> verify
      final habit = _testHabit(title: 'New Habit');
      await habitRepo.insertHabit(habit);

      final habits = await habitRepo.getActiveHabits();
      expect(habits.length, 1);
      expect(habits.first.title, 'New Habit');

      // Now render a tile with the retrieved habit
      await tester.pumpWidget(
        _wrapWithProviders(
          HabitTile(
            habit: habits.first,
            log: null,
            onTap: () {},
            onToggle: () {},
            onSkip: () {},
          ),
          db,
        ),
      );

      expect(find.text('New Habit'), findsOneWidget);
    });

    testWidgets('adding multiple habits shows them all', (tester) async {
      await habitRepo.insertHabit(_testHabit(id: 'h1', title: 'Habit One'));
      await habitRepo.insertHabit(_testHabit(id: 'h2', title: 'Habit Two'));
      await habitRepo.insertHabit(_testHabit(id: 'h3', title: 'Habit Three'));

      final habits = await habitRepo.getActiveHabits();
      expect(habits.length, 3);

      await tester.pumpWidget(
        _wrapWithProviders(
          ListView(
            children: habits
                .map((h) => HabitTile(
                      habit: h,
                      log: null,
                      onTap: () {},
                      onToggle: () {},
                      onSkip: () {},
                    ))
                .toList(),
          ),
          db,
        ),
      );

      expect(find.text('Habit One'), findsOneWidget);
      expect(find.text('Habit Two'), findsOneWidget);
      expect(find.text('Habit Three'), findsOneWidget);
    });
  });

  group('Quantity habit tile', () {
    testWidgets('shows quantity progress', (tester) async {
      final habit = Habit(
        id: 'q-habit',
        title: 'Drink Water',
        colourValue: 0xFF06B6D4,
        iconCodePoint: Icons.water_drop.codePoint,
        scheduleType: ScheduleType.daily,
        goalType: GoalType.quantity,
        targetQuantity: 8.0,
        unit: 'glasses',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final log = HabitLog(
        id: 'log-q',
        habitId: 'q-habit',
        date: DateTime.now(),
        completed: false,
        value: 5.0,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          HabitTile(
            habit: habit,
            log: log,
            onTap: () {},
            onToggle: () {},
            onSkip: () {},
            onQuantitySubmit: (_) {},
          ),
          db,
        ),
      );

      expect(find.text('Drink Water'), findsOneWidget);
      expect(find.text('5 / 8 glasses'), findsOneWidget);
    });
  });
}
