import 'package:drift/drift.dart';
import '../../domain/entities/daily_check_in.dart';
import '../../domain/repositories/context_repository.dart';
import '../database/app_database.dart';
import '../mappers/check_in_mapper.dart';

/// Drift-backed implementation of [ContextRepository].
class DriftContextRepository implements ContextRepository {
  final AppDatabase _db;

  DriftContextRepository(this._db);

  @override
  Future<DailyCheckIn?> getCheckInForDate(DateTime date) async {
    final normalised = DateTime(date.year, date.month, date.day);
    final query = _db.select(_db.dailyCheckIns)
      ..where((c) => c.date.equals(normalised));
    final row = await query.getSingleOrNull();
    return row != null ? CheckInMapper.toDomain(row) : null;
  }

  @override
  Future<List<DailyCheckIn>> getCheckInsInRange(
      DateTime start, DateTime end) async {
    final normStart = DateTime(start.year, start.month, start.day);
    final normEnd = DateTime(end.year, end.month, end.day);
    final query = _db.select(_db.dailyCheckIns)
      ..where((c) =>
          c.date.isBiggerOrEqualValue(normStart) &
          c.date.isSmallerOrEqualValue(normEnd))
      ..orderBy([(c) => OrderingTerm.asc(c.date)]);
    final rows = await query.get();
    return rows.map(CheckInMapper.toDomain).toList();
  }

  @override
  Future<List<DailyCheckIn>> getAllCheckIns() async {
    final query = _db.select(_db.dailyCheckIns)
      ..orderBy([(c) => OrderingTerm.desc(c.date)]);
    final rows = await query.get();
    return rows.map(CheckInMapper.toDomain).toList();
  }

  @override
  Future<void> insertCheckIn(DailyCheckIn checkIn) async {
    await _db
        .into(_db.dailyCheckIns)
        .insert(CheckInMapper.toCompanion(checkIn));
  }

  @override
  Future<void> updateCheckIn(DailyCheckIn checkIn) async {
    await (_db.update(_db.dailyCheckIns)
          ..where((c) => c.id.equals(checkIn.id)))
        .write(CheckInMapper.toCompanion(checkIn));
  }

  @override
  Future<void> deleteCheckIn(String id) async {
    await (_db.delete(_db.dailyCheckIns)..where((c) => c.id.equals(id))).go();
  }

  @override
  Stream<DailyCheckIn?> watchCheckInForDate(DateTime date) {
    final normalised = DateTime(date.year, date.month, date.day);
    final query = _db.select(_db.dailyCheckIns)
      ..where((c) => c.date.equals(normalised));
    return query
        .watchSingleOrNull()
        .map((row) => row != null ? CheckInMapper.toDomain(row) : null);
  }
}
