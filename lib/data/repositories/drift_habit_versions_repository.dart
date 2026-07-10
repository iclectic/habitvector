import '../../domain/entities/habit_versions.dart';
import '../../domain/repositories/habit_versions_repository.dart';
import '../database/app_database.dart';
import '../mappers/habit_versions_mapper.dart';

/// Drift-backed implementation of [HabitVersionsRepository].
class DriftHabitVersionsRepository implements HabitVersionsRepository {
  final AppDatabase _db;

  DriftHabitVersionsRepository(this._db);

  @override
  Future<HabitVersions?> getVersionsForHabit(String habitId) async {
    final query = _db.select(_db.habitVersionsTable)
      ..where((v) => v.habitId.equals(habitId));
    final row = await query.getSingleOrNull();
    return row != null ? HabitVersionsMapper.toDomain(row) : null;
  }

  @override
  Future<void> upsertVersions(HabitVersions versions) async {
    await _db
        .into(_db.habitVersionsTable)
        .insertOnConflictUpdate(HabitVersionsMapper.toCompanion(versions));
  }

  @override
  Future<void> deleteVersionsForHabit(String habitId) async {
    await (_db.delete(_db.habitVersionsTable)
          ..where((v) => v.habitId.equals(habitId)))
        .go();
  }

  @override
  Stream<HabitVersions?> watchVersionsForHabit(String habitId) {
    final query = _db.select(_db.habitVersionsTable)
      ..where((v) => v.habitId.equals(habitId));
    return query.watchSingleOrNull().map(
          (row) => row != null ? HabitVersionsMapper.toDomain(row) : null,
        );
  }
}
