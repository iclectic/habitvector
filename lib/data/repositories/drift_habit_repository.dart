import 'package:drift/drift.dart';
import '../../domain/entities/habit.dart';
import '../../domain/repositories/habit_repository.dart';
import '../database/app_database.dart';
import '../mappers/habit_mapper.dart';

/// Drift-backed implementation of HabitRepository.
class DriftHabitRepository implements HabitRepository {
  final AppDatabase _db;

  DriftHabitRepository(this._db);

  AppDatabase get database => _db;

  @override
  Future<List<Habit>> getAllHabits() async {
    final rows = await _db.select(_db.habits).get();
    return rows.map(HabitMapper.toDomain).toList();
  }

  @override
  Future<List<Habit>> getActiveHabits() async {
    final query = _db.select(_db.habits)
      ..where((h) => h.archived.equals(false));
    final rows = await query.get();
    return rows.map(HabitMapper.toDomain).toList();
  }

  @override
  Future<List<Habit>> getArchivedHabits() async {
    final query = _db.select(_db.habits)..where((h) => h.archived.equals(true));
    final rows = await query.get();
    return rows.map(HabitMapper.toDomain).toList();
  }

  @override
  Future<Habit?> getHabitById(String id) async {
    final query = _db.select(_db.habits)..where((h) => h.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? HabitMapper.toDomain(row) : null;
  }

  @override
  Future<void> insertHabit(Habit habit) async {
    await _db.into(_db.habits).insert(HabitMapper.toCompanion(habit));
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    await (_db.update(_db.habits)..where((h) => h.id.equals(habit.id)))
        .write(HabitMapper.toCompanion(habit));
  }

  @override
  Future<void> deleteHabit(String id) async {
    await (_db.delete(_db.habits)..where((h) => h.id.equals(id))).go();
  }

  @override
  Future<void> archiveHabit(String id) async {
    await (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(
        archived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> unarchiveHabit(String id) async {
    await (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(
        archived: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Stream<List<Habit>> watchActiveHabits() {
    final query = _db.select(_db.habits)
      ..where((h) => h.archived.equals(false))
      ..orderBy([(h) => OrderingTerm.asc(h.createdAt)]);
    return query.watch().map(
          (rows) => rows.map(HabitMapper.toDomain).toList(),
        );
  }

  @override
  Stream<Habit?> watchHabitById(String id) {
    final query = _db.select(_db.habits)..where((h) => h.id.equals(id));
    return query.watchSingleOrNull().map(
          (row) => row != null ? HabitMapper.toDomain(row) : null,
        );
  }
}
