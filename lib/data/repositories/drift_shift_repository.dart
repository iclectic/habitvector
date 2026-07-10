import 'package:drift/drift.dart';
import '../../domain/entities/work_shift.dart';
import '../../domain/repositories/shift_repository.dart';
import '../database/app_database.dart';
import '../mappers/shift_mapper.dart';

/// Drift-backed implementation of [ShiftRepository].
class DriftShiftRepository implements ShiftRepository {
  final AppDatabase _db;

  DriftShiftRepository(this._db);

  @override
  Future<List<WorkShift>> getAllShifts() async {
    final rows = await _db.select(_db.workShifts).get();
    return rows.map(ShiftMapper.toDomain).toList();
  }

  @override
  Future<List<WorkShift>> getActiveShifts() async {
    final query = _db.select(_db.workShifts)
      ..where((s) => s.archived.equals(false))
      ..orderBy([(s) => OrderingTerm.asc(s.startTime)]);
    final rows = await query.get();
    return rows.map(ShiftMapper.toDomain).toList();
  }

  @override
  Future<List<WorkShift>> getShiftsForDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final query = _db.select(_db.workShifts)
      ..where((s) =>
          s.archived.equals(false) &
          s.startTime.isBiggerOrEqualValue(dayStart) &
          s.startTime.isSmallerThanValue(dayEnd));
    final rows = await query.get();
    return rows.map(ShiftMapper.toDomain).toList();
  }

  @override
  Future<List<WorkShift>> getShiftsInRange(
      DateTime start, DateTime end) async {
    final query = _db.select(_db.workShifts)
      ..where((s) =>
          s.archived.equals(false) &
          s.startTime.isBiggerOrEqualValue(start) &
          s.startTime.isSmallerOrEqualValue(end))
      ..orderBy([(s) => OrderingTerm.asc(s.startTime)]);
    final rows = await query.get();
    return rows.map(ShiftMapper.toDomain).toList();
  }

  @override
  Future<WorkShift?> getShiftById(String id) async {
    final query = _db.select(_db.workShifts)
      ..where((s) => s.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? ShiftMapper.toDomain(row) : null;
  }

  @override
  Future<void> insertShift(WorkShift shift) async {
    await _db.into(_db.workShifts).insert(ShiftMapper.toCompanion(shift));
  }

  @override
  Future<void> updateShift(WorkShift shift) async {
    await (_db.update(_db.workShifts)..where((s) => s.id.equals(shift.id)))
        .write(ShiftMapper.toCompanion(shift));
  }

  @override
  Future<void> deleteShift(String id) async {
    await (_db.delete(_db.workShifts)..where((s) => s.id.equals(id))).go();
  }

  @override
  Future<void> archiveShift(String id) async {
    await (_db.update(_db.workShifts)..where((s) => s.id.equals(id))).write(
      WorkShiftsCompanion(
        archived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Stream<List<WorkShift>> watchShiftsForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final query = _db.select(_db.workShifts)
      ..where((s) =>
          s.archived.equals(false) &
          s.startTime.isBiggerOrEqualValue(dayStart) &
          s.startTime.isSmallerThanValue(dayEnd));
    return query.watch().map((rows) => rows.map(ShiftMapper.toDomain).toList());
  }

  @override
  Stream<List<WorkShift>> watchActiveShifts() {
    final query = _db.select(_db.workShifts)
      ..where((s) => s.archived.equals(false))
      ..orderBy([(s) => OrderingTerm.asc(s.startTime)]);
    return query.watch().map((rows) => rows.map(ShiftMapper.toDomain).toList());
  }
}
