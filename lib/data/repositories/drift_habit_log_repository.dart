import 'package:drift/drift.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/repositories/habit_log_repository.dart';
import '../database/app_database.dart';
import '../mappers/habit_log_mapper.dart';

/// Drift-backed implementation of HabitLogRepository.
class DriftHabitLogRepository implements HabitLogRepository {
  final AppDatabase _db;

  DriftHabitLogRepository(this._db);

  DateTime _normalise(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Future<List<HabitLog>> getLogsForHabit(String habitId) async {
    final query = _db.select(_db.habitLogs)
      ..where((l) => l.habitId.equals(habitId))
      ..orderBy([(l) => OrderingTerm.desc(l.date)]);
    final rows = await query.get();
    return rows.map(HabitLogMapper.toDomain).toList();
  }

  @override
  Future<List<HabitLog>> getLogsForHabitInRange(
    String habitId,
    DateTime start,
    DateTime end,
  ) async {
    final s = _normalise(start);
    final e = _normalise(end).add(const Duration(days: 1));
    final query = _db.select(_db.habitLogs)
      ..where((l) =>
          l.habitId.equals(habitId) &
          l.date.isBiggerOrEqualValue(s) &
          l.date.isSmallerThanValue(e))
      ..orderBy([(l) => OrderingTerm.asc(l.date)]);
    final rows = await query.get();
    return rows.map(HabitLogMapper.toDomain).toList();
  }

  @override
  Future<List<HabitLog>> getLogsForDate(DateTime date) async {
    final d = _normalise(date);
    final next = d.add(const Duration(days: 1));
    final query = _db.select(_db.habitLogs)
      ..where(
          (l) => l.date.isBiggerOrEqualValue(d) & l.date.isSmallerThanValue(next));
    final rows = await query.get();
    return rows.map(HabitLogMapper.toDomain).toList();
  }

  @override
  Future<List<HabitLog>> getAllLogsInRange(DateTime start, DateTime end) async {
    final s = _normalise(start);
    final e = _normalise(end).add(const Duration(days: 1));
    final query = _db.select(_db.habitLogs)
      ..where((l) =>
          l.date.isBiggerOrEqualValue(s) & l.date.isSmallerThanValue(e))
      ..orderBy([(l) => OrderingTerm.asc(l.date)]);
    final rows = await query.get();
    return rows.map(HabitLogMapper.toDomain).toList();
  }

  @override
  Future<HabitLog?> getLogForHabitOnDate(String habitId, DateTime date) async {
    final d = _normalise(date);
    final next = d.add(const Duration(days: 1));
    final query = _db.select(_db.habitLogs)
      ..where((l) =>
          l.habitId.equals(habitId) &
          l.date.isBiggerOrEqualValue(d) &
          l.date.isSmallerThanValue(next));
    final row = await query.getSingleOrNull();
    return row != null ? HabitLogMapper.toDomain(row) : null;
  }

  @override
  Future<void> insertLog(HabitLog log) async {
    await _db.into(_db.habitLogs).insert(HabitLogMapper.toCompanion(log));
  }

  @override
  Future<void> updateLog(HabitLog log) async {
    await (_db.update(_db.habitLogs)..where((l) => l.id.equals(log.id)))
        .write(HabitLogMapper.toCompanion(log));
  }

  @override
  Future<void> deleteLog(String id) async {
    await (_db.delete(_db.habitLogs)..where((l) => l.id.equals(id))).go();
  }

  @override
  Future<void> deleteLogsForHabit(String habitId) async {
    await (_db.delete(_db.habitLogs)
          ..where((l) => l.habitId.equals(habitId)))
        .go();
  }

  @override
  Stream<List<HabitLog>> watchLogsForDate(DateTime date) {
    final d = _normalise(date);
    final next = d.add(const Duration(days: 1));
    final query = _db.select(_db.habitLogs)
      ..where(
          (l) => l.date.isBiggerOrEqualValue(d) & l.date.isSmallerThanValue(next));
    return query.watch().map(
          (rows) => rows.map(HabitLogMapper.toDomain).toList(),
        );
  }

  @override
  Stream<List<HabitLog>> watchLogsForHabit(String habitId) {
    final query = _db.select(_db.habitLogs)
      ..where((l) => l.habitId.equals(habitId))
      ..orderBy([(l) => OrderingTerm.desc(l.date)]);
    return query.watch().map(
          (rows) => rows.map(HabitLogMapper.toDomain).toList(),
        );
  }
}
