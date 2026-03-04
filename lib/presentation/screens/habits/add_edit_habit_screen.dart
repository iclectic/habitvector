import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/habit.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';

class AddEditHabitScreen extends ConsumerStatefulWidget {
  final Habit? existingHabit;

  const AddEditHabitScreen({super.key, this.existingHabit});

  @override
  ConsumerState<AddEditHabitScreen> createState() => _AddEditHabitScreenState();
}

class _AddEditHabitScreenState extends ConsumerState<AddEditHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _targetController;
  late TextEditingController _unitController;

  late Color _selectedColour;
  late IconData _selectedIcon;
  late ScheduleType _scheduleType;
  late GoalType _goalType;
  late List<int> _scheduledDays;
  late int _customFrequency;
  late List<TimeOfDay> _reminderTimes;

  bool get _isEditing => widget.existingHabit != null;

  static const List<IconData> _availableIcons = [
    Icons.fitness_center,
    Icons.menu_book,
    Icons.water_drop,
    Icons.self_improvement,
    Icons.directions_run,
    Icons.music_note,
    Icons.code,
    Icons.brush,
    Icons.restaurant,
    Icons.bedtime,
    Icons.smoking_rooms,
    Icons.local_drink,
    Icons.pets,
    Icons.school,
    Icons.work,
    Icons.favorite,
    Icons.star,
    Icons.emoji_nature,
    Icons.sports_soccer,
    Icons.phone_android,
    Icons.cleaning_services,
    Icons.healing,
    Icons.sunny,
    Icons.nightlight,
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.existingHabit;
    _titleController = TextEditingController(text: h?.title ?? '');
    _descriptionController =
        TextEditingController(text: h?.description ?? '');
    _targetController = TextEditingController(
      text: h?.targetQuantity?.toStringAsFixed(
              h.targetQuantity!.truncateToDouble() == h.targetQuantity ? 0 : 1) ??
          '',
    );
    _unitController = TextEditingController(text: h?.unit ?? '');
    _selectedColour = h?.colour ?? AppTheme.habitColours[0];
    _selectedIcon = h?.icon ?? Icons.fitness_center;
    _scheduleType = h?.scheduleType ?? ScheduleType.daily;
    _goalType = h?.goalType ?? GoalType.tick;
    _scheduledDays = h?.scheduledDays.toList() ?? [];
    _customFrequency = h?.customFrequencyPerWeek ?? 3;
    _reminderTimes = h?.reminderTimes.toList() ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Habit' : 'New Habit'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(_isEditing ? 'Update' : 'Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Habit name',
                hintText: 'e.g. Morning Exercise',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a habit name.';
                }
                if (value.trim().length > 200) {
                  return 'Name must be 200 characters or fewer.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add a short description',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Colour picker
            Text(
              'Colour',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: AppTheme.habitColours.map((colour) {
                final selected = _selectedColour.value == colour.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColour = colour),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colour,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(
                              color: theme.colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Icon picker
            Text(
              'Icon',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: _availableIcons.map((icon) {
                final selected = _selectedIcon == icon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? _selectedColour.withOpacity(0.2)
                          : theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: selected
                          ? Border.all(color: _selectedColour, width: 2)
                          : null,
                    ),
                    child: Icon(
                      icon,
                      color: selected ? _selectedColour : theme.colorScheme.onSurface.withOpacity(0.6),
                      size: 22,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Schedule type
            Text(
              'Schedule',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            SegmentedButton<ScheduleType>(
              segments: const [
                ButtonSegment(
                  value: ScheduleType.daily,
                  label: Text('Daily'),
                  icon: Icon(Icons.calendar_today, size: 16),
                ),
                ButtonSegment(
                  value: ScheduleType.specificDays,
                  label: Text('Days'),
                  icon: Icon(Icons.date_range, size: 16),
                ),
                ButtonSegment(
                  value: ScheduleType.customFrequency,
                  label: Text('Weekly'),
                  icon: Icon(Icons.repeat, size: 16),
                ),
              ],
              selected: {_scheduleType},
              onSelectionChanged: (selected) {
                setState(() => _scheduleType = selected.first);
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Schedule details
            if (_scheduleType == ScheduleType.specificDays) _buildDayPicker(theme),
            if (_scheduleType == ScheduleType.customFrequency)
              _buildFrequencyPicker(theme),
            const SizedBox(height: AppTheme.spacingLg),

            // Goal type
            Text(
              'Goal type',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            SegmentedButton<GoalType>(
              segments: const [
                ButtonSegment(
                  value: GoalType.tick,
                  label: Text('Yes/No'),
                  icon: Icon(Icons.check_circle_outline, size: 16),
                ),
                ButtonSegment(
                  value: GoalType.quantity,
                  label: Text('Quantity'),
                  icon: Icon(Icons.numbers, size: 16),
                ),
              ],
              selected: {_goalType},
              onSelectionChanged: (selected) {
                setState(() => _goalType = selected.first);
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),

            if (_goalType == GoalType.quantity) ...[
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _targetController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Target',
                        hintText: 'e.g. 8',
                      ),
                      validator: (value) {
                        if (_goalType == GoalType.quantity) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a target.';
                          }
                          if (double.tryParse(value.trim()) == null) {
                            return 'Enter a valid number.';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        hintText: 'e.g. glasses',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLg),
            ],

            // Reminders
            Text(
              'Reminders',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            ..._reminderTimes.asMap().entries.map((entry) {
              final idx = entry.key;
              final time = entry.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.alarm, color: _selectedColour),
                title: Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    setState(() => _reminderTimes.removeAt(idx));
                  },
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: time,
                  );
                  if (picked != null) {
                    setState(() => _reminderTimes[idx] = picked);
                  }
                },
              );
            }),
            TextButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 9, minute: 0),
                );
                if (picked != null) {
                  setState(() => _reminderTimes.add(picked));
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add reminder'),
            ),
            const SizedBox(height: AppTheme.spacingXxl),
          ],
        ),
      ),
    );
  }

  Widget _buildDayPicker(ThemeData theme) {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(
      spacing: AppTheme.spacingSm,
      children: List.generate(7, (index) {
        final dayNumber = index + 1; // 1=Mon, 7=Sun
        final selected = _scheduledDays.contains(dayNumber);
        return FilterChip(
          label: Text(dayLabels[index]),
          selected: selected,
          onSelected: (value) {
            setState(() {
              if (value) {
                _scheduledDays.add(dayNumber);
                _scheduledDays.sort();
              } else {
                _scheduledDays.remove(dayNumber);
              }
            });
          },
          selectedColor: _selectedColour.withOpacity(0.2),
          checkmarkColor: _selectedColour,
        );
      }),
    );
  }

  Widget _buildFrequencyPicker(ThemeData theme) {
    return Row(
      children: [
        Text(
          'Times per week:',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(width: AppTheme.spacingMd),
        IconButton(
          onPressed: _customFrequency > 1
              ? () => setState(() => _customFrequency--)
              : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(
          '$_customFrequency',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: _customFrequency < 7
              ? () => setState(() => _customFrequency++)
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_scheduleType == ScheduleType.specificDays &&
        _scheduledDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day.')),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    final habitUseCases = ref.read(habitUseCasesProvider);
    final notificationService = ref.read(notificationServiceProvider);

    try {
      if (_isEditing) {
        final updated = widget.existingHabit!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          clearDescription: _descriptionController.text.trim().isEmpty,
          colourValue: _selectedColour.value,
          iconCodePoint: _selectedIcon.codePoint,
          scheduleType: _scheduleType,
          scheduledDays: _scheduledDays,
          customFrequencyPerWeek: _customFrequency,
          goalType: _goalType,
          targetQuantity: _goalType == GoalType.quantity
              ? double.tryParse(_targetController.text.trim())
              : null,
          clearTargetQuantity: _goalType == GoalType.tick,
          unit: _goalType == GoalType.quantity
              ? _unitController.text.trim()
              : null,
          clearUnit: _goalType == GoalType.tick,
          reminderTimes: _reminderTimes,
          updatedAt: DateTime.now(),
        );
        await habitUseCases.updateHabit(updated);
        await notificationService.scheduleHabitReminders(updated);
      } else {
        final habit = await habitUseCases.createHabit(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          colourValue: _selectedColour.value,
          iconCodePoint: _selectedIcon.codePoint,
          scheduleType: _scheduleType,
          scheduledDays: _scheduledDays,
          customFrequencyPerWeek: _customFrequency,
          goalType: _goalType,
          targetQuantity: _goalType == GoalType.quantity
              ? double.tryParse(_targetController.text.trim())
              : null,
          unit: _goalType == GoalType.quantity
              ? _unitController.text.trim()
              : null,
          reminderTimes: _reminderTimes,
        );
        await notificationService.scheduleHabitReminders(habit);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save habit: $e')),
        );
      }
    }
  }
}
