import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/habit.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import 'add_edit_habit_screen.dart';
import 'habit_detail_screen.dart';

/// Sort options for the habits list.
enum HabitSortOption { name, streak, lastCompleted, created }

/// Filter options for schedule type.
enum ScheduleFilter { all, daily, specificDays, customFrequency }

class HabitsListScreen extends ConsumerStatefulWidget {
  const HabitsListScreen({super.key});

  @override
  ConsumerState<HabitsListScreen> createState() => _HabitsListScreenState();
}

class _HabitsListScreenState extends ConsumerState<HabitsListScreen> {
  String _searchQuery = '';
  ScheduleFilter _scheduleFilter = ScheduleFilter.all;
  HabitSortOption _sortOption = HabitSortOption.created;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habitsAsync = ref.watch(activeHabitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Habits'),
        actions: [
          PopupMenuButton<HabitSortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort habits',
            onSelected: (option) => setState(() => _sortOption = option),
            itemBuilder: (_) => [
              _sortMenuItem(HabitSortOption.name, 'Name'),
              _sortMenuItem(HabitSortOption.created, 'Date created'),
              _sortMenuItem(HabitSortOption.streak, 'Streak'),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'habits_fab',
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditHabitScreen()),
          );
        },
        tooltip: 'Add new habit',
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: AppTheme.spacingSm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search habits...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            child: Row(
              children: ScheduleFilter.values.map((filter) {
                final selected = _scheduleFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: AppTheme.spacingSm),
                  child: FilterChip(
                    label: Text(_filterLabel(filter)),
                    selected: selected,
                    onSelected: (_) => setState(() => _scheduleFilter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          // Habits list
          Expanded(
            child: habitsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (habits) {
                // Apply search
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  habits = habits
                      .where((h) =>
                          h.title.toLowerCase().contains(query) ||
                          (h.description?.toLowerCase().contains(query) ??
                              false))
                      .toList();
                }

                // Apply filter
                habits = _applyFilter(habits);

                // Apply sort
                habits = _applySort(habits);

                if (habits.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingXl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No habits match your search.'
                                : 'No habits yet. Tap + to create one.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingSm,
                  ),
                  itemCount: habits.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTheme.spacingSm),
                  itemBuilder: (context, index) {
                    if (index == habits.length) {
                      return const SizedBox(height: 80);
                    }
                    final habit = habits[index];
                    return _HabitListItem(
                      habit: habit,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                HabitDetailScreen(habitId: habit.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<HabitSortOption> _sortMenuItem(
      HabitSortOption option, String label) {
    return PopupMenuItem(
      value: option,
      child: Row(
        children: [
          if (_sortOption == option)
            const Icon(Icons.check_rounded, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  String _filterLabel(ScheduleFilter filter) {
    switch (filter) {
      case ScheduleFilter.all:
        return 'All';
      case ScheduleFilter.daily:
        return 'Daily';
      case ScheduleFilter.specificDays:
        return 'Specific days';
      case ScheduleFilter.customFrequency:
        return 'Custom frequency';
    }
  }

  List<Habit> _applyFilter(List<Habit> habits) {
    switch (_scheduleFilter) {
      case ScheduleFilter.all:
        return habits;
      case ScheduleFilter.daily:
        return habits
            .where((h) => h.scheduleType == ScheduleType.daily)
            .toList();
      case ScheduleFilter.specificDays:
        return habits
            .where((h) => h.scheduleType == ScheduleType.specificDays)
            .toList();
      case ScheduleFilter.customFrequency:
        return habits
            .where((h) => h.scheduleType == ScheduleType.customFrequency)
            .toList();
    }
  }

  List<Habit> _applySort(List<Habit> habits) {
    final sorted = List<Habit>.from(habits);
    switch (_sortOption) {
      case HabitSortOption.name:
        sorted.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case HabitSortOption.created:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case HabitSortOption.streak:
        // Default to created order; streak sorting requires async data
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case HabitSortOption.lastCompleted:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }
    return sorted;
  }
}

class _HabitListItem extends StatelessWidget {
  final Habit habit;
  final VoidCallback onTap;

  const _HabitListItem({required this.habit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: habit.colour.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(habit.icon, color: habit.colour, size: 24),
        ),
        title: Text(
          habit.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _scheduleDescription(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: theme.colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
    );
  }

  String _scheduleDescription() {
    switch (habit.scheduleType) {
      case ScheduleType.daily:
        return 'Daily';
      case ScheduleType.specificDays:
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final days = habit.scheduledDays.map((d) => dayNames[d - 1]).join(', ');
        return days;
      case ScheduleType.customFrequency:
        return '${habit.customFrequencyPerWeek}x per week';
    }
  }
}
