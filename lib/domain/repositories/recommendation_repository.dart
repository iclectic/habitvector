import '../entities/adaptive_recommendation.dart';

/// Abstract interface for recommendation data operations.
abstract class RecommendationRepository {
  Future<AdaptiveRecommendation?> getRecommendationById(String id);
  Future<List<AdaptiveRecommendation>> getRecommendationsForHabit(
      String habitId);
  Future<AdaptiveRecommendation?> getLatestRecommendationForHabit(
      String habitId);
  Future<List<AdaptiveRecommendation>> getRecommendationsForDate(
      DateTime date);
  Future<List<AdaptiveRecommendation>> getRecommendationsInRange(
      DateTime start, DateTime end);
  Future<void> insertRecommendation(AdaptiveRecommendation recommendation);
  Future<void> updateRecommendation(AdaptiveRecommendation recommendation);
  Future<void> deleteRecommendation(String id);
  Stream<List<AdaptiveRecommendation>> watchRecommendationsForDate(
      DateTime date);
}
