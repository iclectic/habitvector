/// Immutable streak information for a habit.
class StreakInfo {
  final String habitId;
  final int currentStreak;
  final int longestStreak;
  final double completionRate7Days;
  final double completionRate30Days;
  final double completionRate90Days;

  const StreakInfo({
    required this.habitId,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.completionRate7Days = 0.0,
    this.completionRate30Days = 0.0,
    this.completionRate90Days = 0.0,
  });

  StreakInfo copyWith({
    String? habitId,
    int? currentStreak,
    int? longestStreak,
    double? completionRate7Days,
    double? completionRate30Days,
    double? completionRate90Days,
  }) {
    return StreakInfo(
      habitId: habitId ?? this.habitId,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      completionRate7Days: completionRate7Days ?? this.completionRate7Days,
      completionRate30Days: completionRate30Days ?? this.completionRate30Days,
      completionRate90Days: completionRate90Days ?? this.completionRate90Days,
    );
  }
}
