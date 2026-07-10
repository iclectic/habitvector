import 'package:drift/drift.dart';
import '../../domain/entities/adaptive_recommendation.dart';
import '../../domain/repositories/recommendation_repository.dart';
import '../database/app_database.dart';
import '../mappers/recommendation_mapper.dart';

/// Drift-backed implementation of [RecommendationRepository].
class DriftRecommendationRepository implements RecommendationRepository {
  final AppDatabase _db;

  DriftRecommendationRepository(this._db);

  @override
  Future<AdaptiveRecommendation?> getRecommendationById(String id) async {
    final query = _db.select(_db.adaptiveRecommendations)
      ..where((r) => r.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? RecommendationMapper.toDomain(row) : null;
  }

  @override
  Future<List<AdaptiveRecommendation>> getRecommendationsForHabit(
      String habitId) async {
    final query = _db.select(_db.adaptiveRecommendations)
      ..where((r) => r.habitId.equals(habitId))
      ..orderBy([(r) => OrderingTerm.desc(r.generatedAt)]);
    final rows = await query.get();
    return rows.map(RecommendationMapper.toDomain).toList();
  }

  @override
  Future<AdaptiveRecommendation?> getLatestRecommendationForHabit(
      String habitId) async {
    final query = _db.select(_db.adaptiveRecommendations)
      ..where((r) => r.habitId.equals(habitId))
      ..orderBy([(r) => OrderingTerm.desc(r.generatedAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row != null ? RecommendationMapper.toDomain(row) : null;
  }

  @override
  Future<List<AdaptiveRecommendation>> getRecommendationsForDate(
      DateTime date) async {
    final normalised = DateTime(date.year, date.month, date.day);
    final query = _db.select(_db.adaptiveRecommendations)
      ..where((r) => r.forDate.equals(normalised));
    final rows = await query.get();
    return rows.map(RecommendationMapper.toDomain).toList();
  }

  @override
  Future<List<AdaptiveRecommendation>> getRecommendationsInRange(
      DateTime start, DateTime end) async {
    final normStart = DateTime(start.year, start.month, start.day);
    final normEnd = DateTime(end.year, end.month, end.day);
    final query = _db.select(_db.adaptiveRecommendations)
      ..where((r) =>
          r.forDate.isBiggerOrEqualValue(normStart) &
          r.forDate.isSmallerOrEqualValue(normEnd))
      ..orderBy([(r) => OrderingTerm.desc(r.generatedAt)]);
    final rows = await query.get();
    return rows.map(RecommendationMapper.toDomain).toList();
  }

  @override
  Future<void> insertRecommendation(
      AdaptiveRecommendation recommendation) async {
    await _db
        .into(_db.adaptiveRecommendations)
        .insert(RecommendationMapper.toCompanion(recommendation));
  }

  @override
  Future<void> updateRecommendation(
      AdaptiveRecommendation recommendation) async {
    await (_db.update(_db.adaptiveRecommendations)
          ..where((r) => r.id.equals(recommendation.id)))
        .write(RecommendationMapper.toCompanion(recommendation));
  }

  @override
  Future<void> deleteRecommendation(String id) async {
    await (_db.delete(_db.adaptiveRecommendations)
          ..where((r) => r.id.equals(id)))
        .go();
  }

  @override
  Stream<List<AdaptiveRecommendation>> watchRecommendationsForDate(
      DateTime date) {
    final normalised = DateTime(date.year, date.month, date.day);
    final query = _db.select(_db.adaptiveRecommendations)
      ..where((r) => r.forDate.equals(normalised));
    return query
        .watch()
        .map((rows) => rows.map(RecommendationMapper.toDomain).toList());
  }
}
