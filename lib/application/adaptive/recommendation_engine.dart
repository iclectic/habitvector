import 'package:uuid/uuid.dart';

import '../../domain/entities/adaptive_recommendation.dart';
import '../../domain/entities/daily_check_in.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/entities/recovery_metrics.dart';
import '../../domain/entities/work_shift.dart';
import '../../domain/repositories/recommendation_repository.dart';
import '../../domain/services/clock.dart';
import 'cold_start_rules.dart';
import 'context_feature_builder.dart';
import 'personalised_scorer.dart';
import 'recovery_analysis_service.dart';

/// Application-layer recommendation engine.
///
/// Routes between two scoring layers based on data sufficiency:
/// - **Cold-start rules** ([ColdStartRules]): applied when fewer than
///   [kMinObservationsForPersonalisation] completed logs exist.
/// - **Personalised scorer** ([PersonalisedScorer]): applied once the user
///   has accumulated sufficient history and context data.
///
/// The engine:
/// - Never silently rearranges a user's habits.
/// - Requires user approval for every suggested change.
/// - Stores every recommendation with its factors, confidence, and version.
/// - Provides an alternative action for every recommendation.
class RecommendationEngine {
  final RecommendationRepository _repo;
  final ColdStartRules _coldStartRules;
  final PersonalisedScorer _personalisedScorer;
  final RecoveryAnalysisService _recoveryService;
  final Clock _clock;
  final Uuid _uuid;

  RecommendationEngine({
    required RecommendationRepository repo,
    ColdStartRules coldStartRules = const ColdStartRules(),
    PersonalisedScorer personalisedScorer = const PersonalisedScorer(),
    RecoveryAnalysisService recoveryService = const RecoveryAnalysisService(),
    Clock clock = const SystemClock(),
    Uuid? uuid,
  })  : _repo = repo,
        _coldStartRules = coldStartRules,
        _personalisedScorer = personalisedScorer,
        _recoveryService = recoveryService,
        _clock = clock,
        _uuid = uuid ?? const Uuid();

  /// Generate (or retrieve a cached) recommendation for [habit] on [forDate].
  ///
  /// If a recommendation already exists for this habit and date, returns it
  /// without regenerating — recommendations are stable within a day.
  ///
  /// Routing:
  /// - < [kMinObservationsForPersonalisation] completed logs → cold-start rules
  /// - ≥ [kMinObservationsForPersonalisation] completed logs → personalised scorer
  Future<AdaptiveRecommendation> recommend({
    required Habit habit,
    required List<HabitLog> recentLogs,
    DailyCheckIn? checkIn,
    WorkShift? todayShift,
    DateTime? forDate,
  }) async {
    final date = _normalisedDate(forDate ?? _clock.today());

    // Return cached recommendation for today if one exists.
    final existing = await _repo.getLatestRecommendationForHabit(habit.id);
    if (existing != null && _normalisedDate(existing.forDate) == date) {
      return existing;
    }

    final features = ContextFeatures(
      habit: habit,
      today: date,
      recentLogs: recentLogs,
      checkIn: checkIn,
      todayShift: todayShift,
    );

    final completedCount =
        recentLogs.where((l) => l.completed && !l.skipped).length;
    final usePersonalised =
        completedCount >= kMinObservationsForPersonalisation;

    final ColdStartResult result;
    final String modelVersion;
    final RecommendationSource source;

    if (usePersonalised) {
      final recovery = _recoveryService.calculate(
        habit: habit,
        logs: recentLogs,
        today: date,
      );
      result = _personalisedScorer.evaluate(features, recovery: recovery);
      modelVersion = kPersonalisedScorerVersion;
      source = RecommendationSource.personalisedScoring;
    } else {
      result = _coldStartRules.evaluate(features);
      modelVersion = kColdStartRulesVersion;
      source = RecommendationSource.coldStartRules;
    }

    final recommendation = AdaptiveRecommendation(
      id: _uuid.v4(),
      habitId: habit.id,
      generatedAt: _clock.now(),
      forDate: date,
      action: result.action,
      suggestedVersion: result.suggestedVersion,
      confidence: result.confidence,
      explanation: result.explanation,
      factorsUsed: result.factorsUsed,
      factorsMissing: result.factorsMissing,
      alternativeAction: result.alternativeAction,
      modelVersion: modelVersion,
      source: source,
    );

    await _repo.insertRecommendation(recommendation);
    return recommendation;
  }

  /// Compute recovery metrics for [habit] from [logs] without generating
  /// a recommendation. Useful for displaying the resilience panel.
  RecoveryMetrics computeRecoveryMetrics({
    required Habit habit,
    required List<HabitLog> logs,
    DateTime? asOf,
  }) {
    return _recoveryService.calculate(
      habit: habit,
      logs: logs,
      today: _normalisedDate(asOf ?? _clock.today()),
    );
  }

  /// Record user feedback on a recommendation.
  ///
  /// Must be called with user-initiated input — never called automatically.
  Future<void> recordFeedback({
    required String recommendationId,
    required RecommendationFeedback feedback,
    String? note,
  }) async {
    final existing = await _repo.getRecommendationById(recommendationId);
    if (existing == null) return;

    final updated = existing.copyWith(
      feedback: feedback,
      feedbackAt: _clock.now(),
      feedbackNote: note,
    );
    await _repo.updateRecommendation(updated);
  }

  /// Record the actual outcome of a recommendation (habit completed or not).
  ///
  /// Called by the habit completion use case, not directly by the user.
  Future<void> recordOutcome({
    required String habitId,
    required bool completed,
    DateTime? completedAt,
  }) async {
    final today = _normalisedDate(_clock.today());
    final existing = await _repo.getLatestRecommendationForHabit(habitId);
    if (existing == null) return;
    if (_normalisedDate(existing.forDate) != today) return;

    final updated = existing.copyWith(
      completed: completed,
      completedAt: completed ? (completedAt ?? _clock.now()) : null,
    );
    await _repo.updateRecommendation(updated);
  }

  DateTime _normalisedDate(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}
