import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../../domain/entities/habit.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _addSampleHabits() async {
    final habitUseCases = ref.read(habitUseCasesProvider);

    final samples = [
      (
        title: 'Drink Water',
        icon: Icons.water_drop,
        colour: AppTheme.habitColours[8],
        goalType: GoalType.quantity,
        target: 8.0,
        unit: 'glasses',
      ),
      (
        title: 'Morning Exercise',
        icon: Icons.fitness_center,
        colour: AppTheme.habitColours[6],
        goalType: GoalType.tick,
        target: null,
        unit: null,
      ),
      (
        title: 'Read for 30 Minutes',
        icon: Icons.menu_book,
        colour: AppTheme.habitColours[0],
        goalType: GoalType.tick,
        target: null,
        unit: null,
      ),
    ];

    for (final sample in samples) {
      await habitUseCases.createHabit(
        title: sample.title,
        colourValue: sample.colour.value,
        iconCodePoint: sample.icon.codePoint,
        scheduleType: ScheduleType.daily,
        goalType: sample.goalType,
        targetQuantity: sample.target,
        unit: sample.unit,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingSm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onComplete,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildPage(
                    icon: Icons.track_changes_rounded,
                    title: 'Build Better Habits',
                    description:
                        'Track your daily habits, build streaks, and stay consistent. '
                        'Habit Vector makes it simple to build the routines that matter to you.',
                    theme: theme,
                  ),
                  _buildPage(
                    icon: Icons.local_fire_department_rounded,
                    title: 'Streaks Keep You Going',
                    description:
                        'Every day you complete a habit, your streak grows. '
                        'Watch your progress over weeks and months with clear, simple insights.',
                    theme: theme,
                  ),
                  _buildPage(
                    icon: Icons.rocket_launch_rounded,
                    title: 'Ready to Start?',
                    description:
                        'You can add your own habits or start with a few samples. '
                        'Everything stays on your device, private and secure.',
                    theme: theme,
                    isLast: true,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  if (_currentPage < 2)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        child: const Text('Next'),
                      ),
                    )
                  else
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              HapticFeedback.mediumImpact();
                              await _addSampleHabits();
                              widget.onComplete();
                            },
                            child: const Text('Start with Sample Habits'),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingSm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              widget.onComplete();
                            },
                            child: const Text('Start from Scratch'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    required IconData icon,
    required String title,
    required String description,
    required ThemeData theme,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 56,
              color: theme.colorScheme.primary,
              semanticLabel: title,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
