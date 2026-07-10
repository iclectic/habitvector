import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/entities/adaptive_recommendation.dart';
import '../../domain/entities/habit_versions.dart';
import '../database/app_database.dart';

/// Maps between domain [AdaptiveRecommendation] and Drift [AdaptiveRecommendationRow].
class RecommendationMapper {
  static AdaptiveRecommendation toDomain(AdaptiveRecommendationRow db) {
    final factorsUsed = (jsonDecode(db.factorsUsed) as List<dynamic>)
        .map((e) => e as String)
        .toList();
    final factorsMissing = (jsonDecode(db.factorsMissing) as List<dynamic>)
        .map((e) => e as String)
        .toList();

    return AdaptiveRecommendation(
      id: db.id,
      habitId: db.habitId,
      generatedAt: db.generatedAt,
      forDate: db.forDate,
      action: RecommendedAction.values[db.action],
      suggestedVersion: db.suggestedVersion != null
          ? HabitVersionLevel.values[db.suggestedVersion!]
          : null,
      confidence: db.confidence,
      explanation: db.explanation,
      factorsUsed: factorsUsed,
      factorsMissing: factorsMissing,
      alternativeAction: RecommendedAction.values[db.alternativeAction],
      modelVersion: db.modelVersion,
      source: RecommendationSource.values[db.source],
      feedback: db.feedback != null
          ? RecommendationFeedback.values[db.feedback!]
          : null,
      feedbackAt: db.feedbackAt,
      feedbackNote: db.feedbackNote,
      completed: db.completed,
      completedVersion: db.completedVersion != null
          ? HabitVersionLevel.values[db.completedVersion!]
          : null,
      completedAt: db.completedAt,
    );
  }

  static AdaptiveRecommendationsCompanion toCompanion(
      AdaptiveRecommendation r) {
    return AdaptiveRecommendationsCompanion.insert(
      id: r.id,
      habitId: r.habitId,
      generatedAt: r.generatedAt,
      forDate: DateTime(r.forDate.year, r.forDate.month, r.forDate.day),
      action: r.action.index,
      confidence: r.confidence,
      explanation: r.explanation,
      alternativeAction: r.alternativeAction.index,
      modelVersion: r.modelVersion,
      source: r.source.index,
    ).copyWith(
      suggestedVersion: r.suggestedVersion != null
          ? Value(r.suggestedVersion!.index)
          : const Value(null),
      factorsUsed: Value(jsonEncode(r.factorsUsed)),
      factorsMissing: Value(jsonEncode(r.factorsMissing)),
      feedback:
          r.feedback != null ? Value(r.feedback!.index) : const Value(null),
      feedbackAt:
          r.feedbackAt != null ? Value(r.feedbackAt) : const Value(null),
      feedbackNote:
          r.feedbackNote != null ? Value(r.feedbackNote) : const Value(null),
      completed:
          r.completed != null ? Value(r.completed) : const Value(null),
      completedVersion: r.completedVersion != null
          ? Value(r.completedVersion!.index)
          : const Value(null),
      completedAt:
          r.completedAt != null ? Value(r.completedAt) : const Value(null),
    );
  }
}
