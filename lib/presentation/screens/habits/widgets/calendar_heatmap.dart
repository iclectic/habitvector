import 'package:flutter/material.dart';
import '../../../../domain/entities/habit.dart';
import '../../../../domain/entities/habit_log.dart';
import '../../../theme/app_theme.dart';

/// A 90-day calendar heatmap showing habit completion density.
class CalendarHeatmap extends StatelessWidget {
  final List<HabitLog> logs;
  final Habit habit;
  final Color colour;

  const CalendarHeatmap({
    super.key,
    required this.logs,
    required this.habit,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build a set of completed dates
    final completedDates = <DateTime>{};
    final skippedDates = <DateTime>{};
    for (final log in logs) {
      final d = DateTime(log.date.year, log.date.month, log.date.day);
      if (log.skipped) {
        skippedDates.add(d);
      } else if (_isCompleted(log)) {
        completedDates.add(d);
      }
    }

    // Generate 90 days of data
    final startDate = today.subtract(const Duration(days: 89));

    // Calculate grid: 13 weeks x 7 days
    final firstMonday = startDate.subtract(
      Duration(days: (startDate.weekday - 1) % 7),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day labels
            Row(
              children: [
                const SizedBox(width: 28),
                ...['M', 'T', 'W', 'T', 'F', 'S', 'S'].map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Calendar grid
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.vertical,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 13,
                itemBuilder: (context, weekIndex) {
                  final weekStart =
                      firstMonday.add(Duration(days: weekIndex * 7));

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        // Week label (month abbreviation on first week of month)
                        SizedBox(
                          width: 28,
                          child: _weekLabel(theme, weekStart),
                        ),
                        ...List.generate(7, (dayIndex) {
                          final date =
                              weekStart.add(Duration(days: dayIndex));
                          final isBeforeStart = date.isBefore(startDate);
                          final isAfterToday = date.isAfter(today);
                          final isCompleted = completedDates.contains(date);
                          final isSkipped = skippedDates.contains(date);

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(1),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Tooltip(
                                  message: isBeforeStart || isAfterToday
                                      ? ''
                                      : '${date.day}/${date.month}: ${isCompleted ? "Completed" : isSkipped ? "Skipped" : "Missed"}',
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isBeforeStart || isAfterToday
                                          ? Colors.transparent
                                          : isCompleted
                                              ? colour
                                              : isSkipped
                                                  ? AppTheme.warningColour
                                                      .withOpacity(0.3)
                                                  : theme.colorScheme
                                                      .surfaceContainerHighest
                                                      .withOpacity(0.5),
                                      borderRadius:
                                          BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _legendItem(
                  theme,
                  'Missed',
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                _legendItem(theme, 'Skipped',
                    AppTheme.warningColour.withOpacity(0.3)),
                const SizedBox(width: AppTheme.spacingMd),
                _legendItem(theme, 'Done', colour),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isCompleted(HabitLog log) {
    if (habit.goalType == GoalType.tick) return log.completed;
    if (habit.targetQuantity != null && log.value != null) {
      return log.value! >= habit.targetQuantity!;
    }
    return log.completed;
  }

  Widget _weekLabel(ThemeData theme, DateTime weekStart) {
    // Show month abbreviation if this week contains the 1st of a month
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      if (date.day <= 7 && date.day >= 1) {
        final months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        return Text(
          months[date.month - 1],
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 9,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _legendItem(ThemeData theme, String label, Color colour) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}
