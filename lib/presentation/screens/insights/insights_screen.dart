import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/entities/habit_log.dart';
import '../../../domain/entities/streak_info.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  List<Habit> _habits = [];
  Map<String, List<HabitLog>> _habitLogs = {};
  Map<String, StreakInfo> _streaks = {};
  bool _loading = true;
  bool _showMonthly = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final habitUseCases = ref.read(habitUseCasesProvider);
    final logUseCases = ref.read(logUseCasesProvider);
    final streakCalc = ref.read(streakCalculatorProvider);

    final habits = await habitUseCases.getActiveHabits();
    final logs = <String, List<HabitLog>>{};
    final streaks = <String, StreakInfo>{};

    for (final habit in habits) {
      final habitLogs = await logUseCases.getLogsForHabit(habit.id);
      logs[habit.id] = habitLogs;
      streaks[habit.id] = streakCalc.calculate(habit, habitLogs);
    }

    if (mounted) {
      setState(() {
        _habits = habits;
        _habitLogs = logs;
        _streaks = streaks;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? _buildEmptyState(theme)
              : RefreshIndicator(
                  onRefresh: () async => _loadData(),
                  child: ListView(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    children: [
                      // Period toggle
                      _buildPeriodToggle(theme),
                      const SizedBox(height: AppTheme.spacingLg),

                      // Completion chart
                      Text(
                        _showMonthly
                            ? 'Monthly Completion'
                            : 'Weekly Completion',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      _buildCompletionChart(theme),
                      const SizedBox(height: AppTheme.spacingLg),

                      // Best performing habits
                      Text(
                        'Best Performing',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      _buildPerformanceList(theme, best: true),
                      const SizedBox(height: AppTheme.spacingLg),

                      // Struggling habits
                      Text(
                        'Needs Attention',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      _buildPerformanceList(theme, best: false),
                      const SizedBox(height: AppTheme.spacingLg),

                      // Overall stats
                      _buildOverallStats(theme),
                      const SizedBox(height: AppTheme.spacingXxl),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insights_rounded,
              size: 72,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'No insights yet',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Start tracking habits to see your progress and insights here.',
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

  Widget _buildPeriodToggle(ThemeData theme) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('Weekly')),
        ButtonSegment(value: true, label: Text('Monthly')),
      ],
      selected: {_showMonthly},
      onSelectionChanged: (selected) {
        setState(() => _showMonthly = selected.first);
      },
    );
  }

  Widget _buildCompletionChart(ThemeData theme) {
    final days = _showMonthly ? 30 : 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate daily completion rates
    final spots = <FlSpot>[];
    for (int i = days - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      int totalDue = 0;
      int totalDone = 0;

      for (final habit in _habits) {
        if (habit.isDueOn(date)) {
          totalDue++;
          final logs = _habitLogs[habit.id] ?? [];
          final normalised = DateTime(date.year, date.month, date.day);
          final hasCompleted = logs.any((log) {
            final logDate =
                DateTime(log.date.year, log.date.month, log.date.day);
            return logDate == normalised && _isLogCompleted(habit, log);
          });
          if (hasCompleted) totalDone++;
        }
      }

      final rate = totalDue > 0 ? totalDone / totalDue : 0.0;
      spots.add(FlSpot((days - 1 - i).toDouble(), rate * 100));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.onSurface.withOpacity(0.1),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 25,
                    getTitlesWidget: (value, _) => Text(
                      '${value.toInt()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: _showMonthly ? 7 : 1,
                    getTitlesWidget: (value, _) {
                      if (_showMonthly) {
                        final dayIndex = (days - 1 - value.toInt());
                        final date = today.subtract(Duration(days: dayIndex));
                        return Text(
                          '${date.day}/${date.month}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 9,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        );
                      } else {
                        final dayNames = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun'
                        ];
                        final dayIndex = (days - 1 - value.toInt());
                        final date = today.subtract(Duration(days: dayIndex));
                        return Text(
                          dayNames[date.weekday - 1],
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        );
                      }
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (days - 1).toDouble(),
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: theme.colorScheme.primary,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: !_showMonthly,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: theme.colorScheme.primary,
                      strokeWidth: 1.5,
                      strokeColor: theme.colorScheme.surface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      return LineTooltipItem(
                        '${spot.y.toInt()}%',
                        TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceList(ThemeData theme, {required bool best}) {
    // Sort habits by 30-day completion rate
    final sorted = _habits.toList()
      ..sort((a, b) {
        final rateA = _streaks[a.id]?.completionRate30Days ?? 0;
        final rateB = _streaks[b.id]?.completionRate30Days ?? 0;
        return best ? rateB.compareTo(rateA) : rateA.compareTo(rateB);
      });

    final topHabits = sorted.take(3).toList();

    if (topHabits.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Text(
            'No data yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingSm),
        child: Column(
          children: topHabits.map((habit) {
            final streak = _streaks[habit.id];
            final rate = streak?.completionRate30Days ?? 0;
            final percentage = (rate * 100).toInt();

            return ListTile(
              dense: true,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: habit.colour.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(habit.icon, color: habit.colour, size: 18),
              ),
              title: Text(
                habit.title,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'Streak: ${streak?.currentStreak ?? 0}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: Text(
                '$percentage%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _rateColour(rate),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOverallStats(ThemeData theme) {
    int totalStreaks = 0;
    double avgRate = 0;

    for (final habit in _habits) {
      final streak = _streaks[habit.id];
      if (streak != null) {
        totalStreaks += streak.currentStreak;
        avgRate += streak.completionRate30Days;
      }
    }

    if (_habits.isNotEmpty) {
      avgRate /= _habits.length;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Summary',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Row(
              children: [
                Expanded(
                  child: _miniStat(
                    theme,
                    'Active Habits',
                    '${_habits.length}',
                    Icons.list_rounded,
                  ),
                ),
                Expanded(
                  child: _miniStat(
                    theme,
                    'Total Streaks',
                    '$totalStreaks',
                    Icons.local_fire_department_rounded,
                  ),
                ),
                Expanded(
                  child: _miniStat(
                    theme,
                    'Avg. Rate',
                    '${(avgRate * 100).toInt()}%',
                    Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(ThemeData theme, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _rateColour(double rate) {
    if (rate >= 0.8) return AppTheme.successColour;
    if (rate >= 0.5) return AppTheme.warningColour;
    return AppTheme.errorLight;
  }

  bool _isLogCompleted(Habit habit, HabitLog log) {
    if (log.skipped) return false;
    if (habit.goalType == GoalType.tick) return log.completed;
    if (habit.targetQuantity != null && log.value != null) {
      return log.value! >= habit.targetQuantity!;
    }
    return log.completed;
  }
}
