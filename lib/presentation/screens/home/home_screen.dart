import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/entities/habit_log.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../habits/add_edit_habit_screen.dart';
import '../habits/habit_detail_screen.dart';
import 'widgets/habit_tile.dart';
import 'widgets/summary_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateFormat = DateFormat('EEEE, d MMMM');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Habit Vector'),
            Text(
              dateFormat.format(today),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        toolbarHeight: 64,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_fab',
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddEditHabitScreen(),
            ),
          );
        },
        tooltip: 'Add new habit',
        child: const Icon(Icons.add_rounded),
      ),
      body: _HomeBody(today: today),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  final DateTime today;

  const _HomeBody({required this.today});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(activeHabitsProvider);
    final logsAsync = ref.watch(todayLogsProvider);

    return habitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Text(
            'Something went wrong loading your habits. Please try again.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
      data: (habitsRaw) {
        final habits = habitsRaw.cast<Habit>();
        final todayHabits = habits.where((h) => h.isDueOn(today)).toList();

        return logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading logs: $e')),
          data: (logsRaw) {
            final logs = logsRaw.cast<HabitLog>();
            final logMap = <String, HabitLog>{};
            for (final log in logs) {
              logMap[log.habitId] = log;
            }

            return _buildContent(context, ref, todayHabits, logMap, habits);
          },
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Habit> todayHabits,
    Map<String, HabitLog> logMap,
    List<Habit> allHabits,
  ) {
    final theme = Theme.of(context);
    final completedCount =
        todayHabits.where((h) => logMap[h.id]?.completed == true).length;
    final totalDue = todayHabits.length;
    final completionPct = totalDue > 0 ? completedCount / totalDue : 0.0;

    if (allHabits.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(activeHabitsProvider);
        ref.invalidate(todayLogsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
        children: [
          const SizedBox(height: AppTheme.spacingMd),
          // Summary cards
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  title: 'Today',
                  value: '$completedCount / $totalDue',
                  subtitle: 'habits completed',
                  icon: Icons.check_circle_rounded,
                  colour: AppTheme.successColour,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: SummaryCard(
                  title: 'Completion',
                  value: '${(completionPct * 100).toInt()}%',
                  subtitle: 'today so far',
                  icon: Icons.pie_chart_rounded,
                  colour: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),
          // Section header
          Text(
            'Due Today',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            semanticsLabel: 'Habits due today',
          ),
          const SizedBox(height: AppTheme.spacingSm),
          if (todayHabits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXl),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.celebration_rounded,
                      size: 48,
                      color: theme.colorScheme.primary.withOpacity(0.4),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Text(
                      'No habits due today. Enjoy your rest!',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...todayHabits.map(
              (habit) => Padding(
                padding:
                    const EdgeInsets.only(bottom: AppTheme.spacingSm),
                child: HabitTile(
                  habit: habit,
                  log: logMap[habit.id],
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HabitDetailScreen(habitId: habit.id),
                      ),
                    );
                  },
                  onToggle: () => _toggleHabit(ref, habit, logMap[habit.id]),
                  onSkip: () => _skipHabit(ref, habit),
                  onQuantitySubmit: (value) =>
                      _logQuantity(ref, habit, value),
                ),
              ),
            ),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.track_changes_rounded,
              size: 72,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'No habits yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Tap the + button to create your first habit and start building consistency.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleHabit(
      WidgetRef ref, Habit habit, HabitLog? existingLog) async {
    HapticFeedback.mediumImpact();
    final logUseCases = ref.read(logUseCasesProvider);
    if (existingLog?.completed == true) {
      await logUseCases.markUndone(habit.id);
    } else {
      await logUseCases.markDone(habit.id);
    }
  }

  Future<void> _skipHabit(WidgetRef ref, Habit habit) async {
    HapticFeedback.lightImpact();
    await ref.read(logUseCasesProvider).skip(habit.id);
  }

  Future<void> _logQuantity(
      WidgetRef ref, Habit habit, double value) async {
    HapticFeedback.mediumImpact();
    await ref.read(logUseCasesProvider).logQuantity(habit.id, value, habit);
  }
}
