import 'habit_versions.dart';

/// The action recommended by the engine.
enum RecommendedAction {
  completeStandard,
  useMinimumVersion,
  attemptStretchVersion,
  moveToAnotherTime,
  changeReminderTime,
  pairWithDifferentCue,
  scheduleRecoveryDay,
  leavePlanUnchanged,
}

/// How the user responded to the recommendation.
enum RecommendationFeedback {
  accepted,
  modified,
  rejected,
  ignored,
}

/// The source layer that produced this recommendation.
enum RecommendationSource {
  coldStartRules,
  personalisedScoring,
}

/// An explainable recommendation produced by the recommendation engine.
///
/// Every recommendation must include:
/// - The action suggested
/// - A confidence level (0.0–1.0) with clear meaning
/// - The factors that influenced the decision
/// - The factors that were unavailable
/// - An alternative action
/// - The model/rules version that produced it
///
/// User feedback (accepted/modified/rejected) and the eventual completion
/// outcome are stored here so recommendation quality can be evaluated.
class AdaptiveRecommendation {
  final String id;
  final String habitId;
  final DateTime generatedAt;
  final DateTime forDate;
  final RecommendedAction action;
  final HabitVersionLevel? suggestedVersion;

  /// 0.0–1.0. Reflects data sufficiency, not claimed prediction accuracy.
  final double confidence;

  /// Human-readable explanation of what drove this recommendation.
  final String explanation;

  /// Factors that were available and used (e.g. "rest day", "high energy").
  final List<String> factorsUsed;

  /// Factors that would have improved the recommendation but were absent.
  final List<String> factorsMissing;

  /// Alternative action if the user rejects the primary.
  final RecommendedAction alternativeAction;

  /// Version identifier of the rules or model that produced this.
  final String modelVersion;

  final RecommendationSource source;

  // Feedback fields — populated after the user sees and responds.
  final RecommendationFeedback? feedback;
  final DateTime? feedbackAt;
  final String? feedbackNote;

  // Outcome — populated after the habit is or is not completed.
  final bool? completed;
  final HabitVersionLevel? completedVersion;
  final DateTime? completedAt;

  const AdaptiveRecommendation({
    required this.id,
    required this.habitId,
    required this.generatedAt,
    required this.forDate,
    required this.action,
    this.suggestedVersion,
    required this.confidence,
    required this.explanation,
    required this.factorsUsed,
    required this.factorsMissing,
    required this.alternativeAction,
    required this.modelVersion,
    required this.source,
    this.feedback,
    this.feedbackAt,
    this.feedbackNote,
    this.completed,
    this.completedVersion,
    this.completedAt,
  });

  AdaptiveRecommendation copyWith({
    String? id,
    String? habitId,
    DateTime? generatedAt,
    DateTime? forDate,
    RecommendedAction? action,
    HabitVersionLevel? suggestedVersion,
    bool clearSuggestedVersion = false,
    double? confidence,
    String? explanation,
    List<String>? factorsUsed,
    List<String>? factorsMissing,
    RecommendedAction? alternativeAction,
    String? modelVersion,
    RecommendationSource? source,
    RecommendationFeedback? feedback,
    bool clearFeedback = false,
    DateTime? feedbackAt,
    bool clearFeedbackAt = false,
    String? feedbackNote,
    bool clearFeedbackNote = false,
    bool? completed,
    bool clearCompleted = false,
    HabitVersionLevel? completedVersion,
    bool clearCompletedVersion = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return AdaptiveRecommendation(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      generatedAt: generatedAt ?? this.generatedAt,
      forDate: forDate ?? this.forDate,
      action: action ?? this.action,
      suggestedVersion: clearSuggestedVersion
          ? null
          : (suggestedVersion ?? this.suggestedVersion),
      confidence: confidence ?? this.confidence,
      explanation: explanation ?? this.explanation,
      factorsUsed: factorsUsed ?? this.factorsUsed,
      factorsMissing: factorsMissing ?? this.factorsMissing,
      alternativeAction: alternativeAction ?? this.alternativeAction,
      modelVersion: modelVersion ?? this.modelVersion,
      source: source ?? this.source,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      feedbackAt: clearFeedbackAt ? null : (feedbackAt ?? this.feedbackAt),
      feedbackNote:
          clearFeedbackNote ? null : (feedbackNote ?? this.feedbackNote),
      completed: clearCompleted ? null : (completed ?? this.completed),
      completedVersion: clearCompletedVersion
          ? null
          : (completedVersion ?? this.completedVersion),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdaptiveRecommendation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
