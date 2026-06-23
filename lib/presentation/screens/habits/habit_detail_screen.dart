import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/entities/habit_log.dart';
import '../../../domain/entities/streak_info.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import 'add_edit_habit_screen.dart';
import 'widgets/calendar_heatmap.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  final String habitId;

  const HabitDetailScreen({super.key, required this.habitId});

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  Habit? _habit;
  List<HabitLog> _logs = [];
  StreakInfo? _streakInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final habitUseCases = ref.read(habitUseCasesProvider);
    final logUseCases = ref.read(logUseCasesProvider);
    final streakCalc = ref.read(streakCalculatorProvider);

    final habit = await habitUseCases.getHabitById(widget.habitId);
    if (habit == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final logs = await logUseCases.getLogsForHabit(widget.habitId);
    final streakInfo = streakCalc.calculate(habit, logs);

    if (mounted) {
      setState(() {
        _habit = habit;
        _logs = logs;
        _streakInfo = streakInfo;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_habit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Habit not found.')),
      );
    }

    final habit = _habit!;
    final streak = _streakInfo!;

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit habit',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddEditHabitScreen(existingHabit: habit),
                ),
              );
              _loadData();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'archive') {
                await _archiveHabit();
              } else if (value == 'delete') {
                await _deleteHabit();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(
                      habit.archived
                          ? Icons.unarchive_rounded
                          : Icons.archive_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(habit.archived ? 'Unarchive' : 'Archive'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            // Habit header
            _buildHeader(theme, habit),
            const SizedBox(height: AppTheme.spacingLg),

            // Streak stats
            _buildStreakCards(theme, streak),
            const SizedBox(height: AppTheme.spacingLg),

            // Completion rates
            _buildCompletionRates(theme, streak),
            const SizedBox(height: AppTheme.spacingLg),

            // Calendar heatmap
            Text(
              'Last 90 Days',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            CalendarHeatmap(
              logs: _logs,
              habit: habit,
              colour: habit.colour,
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Description
            if (habit.description != null && habit.description!.isNotEmpty) ...[
              Text(
                'Description',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: Text(
                    habit.description!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
            ],

            // Schedule info
            _buildScheduleInfo(theme, habit),
            const SizedBox(height: AppTheme.spacingXxl),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Habit habit) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: habit.colour.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Icon(habit.icon, color: habit.colour, size: 32),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                habit.title,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (habit.goalType == GoalType.quantity)
                Text(
                  'Target: ${habit.targetQuantity?.toStringAsFixed(habit.targetQuantity!.truncateToDouble() == habit.targetQuantity ? 0 : 1) ?? "?"} ${habit.unit ?? ""}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCards(ThemeData theme, StreakInfo streak) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Current Streak',
            value: '${streak.currentStreak}',
            icon: Icons.local_fire_department_rounded,
            colour: AppTheme.warningColour,
          ),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: _StatCard(
            label: 'Longest Streak',
            value: '${streak.longestStreak}',
            icon: Icons.emoji_events_rounded,
            colour: AppTheme.habitColours[0],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionRates(ThemeData theme, StreakInfo streak) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Completion Rate',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            _RateRow(
              label: 'Last 7 days',
              rate: streak.completionRate7Days,
              colour: _habit!.colour,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            _RateRow(
              label: 'Last 30 days',
              rate: streak.completionRate30Days,
              colour: _habit!.colour,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            _RateRow(
              label: 'Last 90 days',
              rate: streak.completionRate90Days,
              colour: _habit!.colour,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleInfo(ThemeData theme, Habit habit) {
    String scheduleText;
    switch (habit.scheduleType) {
      case ScheduleType.daily:
        scheduleText = 'Every day';
        break;
      case ScheduleType.specificDays:
        final dayNames = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        scheduleText =
            habit.scheduledDays.map((d) => dayNames[d - 1]).join(', ');
        break;
      case ScheduleType.customFrequency:
        scheduleText = '${habit.customFrequencyPerWeek} times per week';
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 18, color: habit.colour),
                const SizedBox(width: AppTheme.spacingSm),
                Text(scheduleText, style: theme.textTheme.bodyMedium),
              ],
            ),
            if (habit.reminderTimes.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Row(
                children: [
                  Icon(Icons.alarm_rounded, size: 18, color: habit.colour),
                  const SizedBox(width: AppTheme.spacingSm),
                  Text(
                    habit.reminderTimes
                        .map((t) =>
                            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
                        .join(', '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _archiveHabit() async {
    HapticFeedback.mediumImpact();
    final habitUseCases = ref.read(habitUseCasesProvider);
    if (_habit!.archived) {
      await habitUseCases.unarchiveHabit(widget.habitId);
    } else {
      await habitUseCases.archiveHabit(widget.habitId);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteHabit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Habit'),
        content: const Text(
          'Are you sure you want to delete this habit? All associated logs will also be deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.heavyImpact();
      final habitUseCases = ref.read(habitUseCasesProvider);
      final logUseCases = ref.read(logUseCasesProvider);

      await logUseCases.deleteLogsForHabit(widget.habitId);
      await habitUseCases.deleteHabit(widget.habitId);

      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color colour;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            Icon(icon, color: colour, size: 28),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colour,
              ),
              semanticsLabel: '$label: $value',
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  final String label;
  final double rate;
  final Color colour;

  const _RateRow({
    required this.label,
    required this.rate,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (rate * 100).toInt();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            Text(
              '$percentage%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colour,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate,
            backgroundColor: colour.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(colour),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
