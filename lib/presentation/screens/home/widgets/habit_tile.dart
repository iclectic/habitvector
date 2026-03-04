import 'package:flutter/material.dart';
import '../../../../domain/entities/habit.dart';
import '../../../../domain/entities/habit_log.dart';
import '../../../theme/app_theme.dart';

/// A single habit tile for the today dashboard.
class HabitTile extends StatefulWidget {
  final Habit habit;
  final HabitLog? log;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onSkip;
  final ValueChanged<double>? onQuantitySubmit;

  const HabitTile({
    super.key,
    required this.habit,
    this.log,
    required this.onTap,
    required this.onToggle,
    required this.onSkip,
    this.onQuantitySubmit,
  });

  @override
  State<HabitTile> createState() => _HabitTileState();
}

class _HabitTileState extends State<HabitTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = widget.log?.completed == true;
    final isSkipped = widget.log?.skipped == true;
    final habitColour = widget.habit.colour;

    return ScaleTransition(
      scale: _scaleAnim,
      child: Card(
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Row(
              children: [
                // Habit icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: habitColour.withOpacity(isCompleted ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    widget.habit.icon,
                    color: habitColour,
                    size: 24,
                    semanticLabel: widget.habit.title,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                // Title and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.habit.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: isCompleted
                              ? theme.colorScheme.onSurface.withOpacity(0.5)
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _buildSubtitle(theme, isCompleted, isSkipped),
                    ],
                  ),
                ),
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isCompleted && !isSkipped)
                      IconButton(
                        icon: Icon(
                          Icons.skip_next_rounded,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                          size: 20,
                        ),
                        onPressed: widget.onSkip,
                        tooltip: 'Skip',
                        visualDensity: VisualDensity.compact,
                      ),
                    _buildMainAction(theme, isCompleted, isSkipped, habitColour),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(ThemeData theme, bool isCompleted, bool isSkipped) {
    if (isSkipped) {
      return Text(
        'Skipped',
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppTheme.warningColour,
        ),
      );
    }

    if (widget.habit.goalType == GoalType.quantity) {
      final current = widget.log?.value ?? 0.0;
      final target = widget.habit.targetQuantity ?? 0.0;
      final unit = widget.habit.unit ?? '';
      return Text(
        '${current.toStringAsFixed(current.truncateToDouble() == current ? 0 : 1)} / ${target.toStringAsFixed(target.truncateToDouble() == target ? 0 : 1)} $unit',
        style: theme.textTheme.bodySmall?.copyWith(
          color: isCompleted
              ? AppTheme.successColour
              : theme.colorScheme.onSurface.withOpacity(0.5),
        ),
      );
    }

    return Text(
      isCompleted ? 'Completed' : _scheduleLabel(),
      style: theme.textTheme.bodySmall?.copyWith(
        color: isCompleted
            ? AppTheme.successColour
            : theme.colorScheme.onSurface.withOpacity(0.5),
      ),
    );
  }

  String _scheduleLabel() {
    switch (widget.habit.scheduleType) {
      case ScheduleType.daily:
        return 'Daily';
      case ScheduleType.specificDays:
        return 'Scheduled days';
      case ScheduleType.customFrequency:
        return '${widget.habit.customFrequencyPerWeek}x per week';
    }
  }

  Widget _buildMainAction(
      ThemeData theme, bool isCompleted, bool isSkipped, Color habitColour) {
    if (widget.habit.goalType == GoalType.quantity && !isCompleted) {
      return IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: habitColour.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.add_rounded,
            color: habitColour,
            size: 20,
          ),
        ),
        onPressed: () => _showQuantityDialog(),
        tooltip: 'Add value',
        visualDensity: VisualDensity.compact,
      );
    }

    return GestureDetector(
      onTap: () {
        _animController.forward().then((_) {
          _animController.reverse();
        });
        widget.onToggle();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isCompleted
              ? habitColour
              : isSkipped
                  ? AppTheme.warningColour.withOpacity(0.2)
                  : habitColour.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: isCompleted
                ? habitColour
                : isSkipped
                    ? AppTheme.warningColour
                    : habitColour.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: isCompleted
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : isSkipped
                ? Icon(Icons.skip_next_rounded,
                    color: AppTheme.warningColour, size: 16)
                : null,
      ),
    );
  }

  void _showQuantityDialog() {
    final controller = TextEditingController();
    final currentValue = widget.log?.value;
    if (currentValue != null) {
      controller.text = currentValue.toStringAsFixed(
          currentValue.truncateToDouble() == currentValue ? 0 : 1);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log ${widget.habit.title}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Value',
            suffixText: widget.habit.unit ?? '',
            hintText: 'Enter amount',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && widget.onQuantitySubmit != null) {
                widget.onQuantitySubmit!(value);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
