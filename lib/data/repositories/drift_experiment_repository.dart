import 'package:drift/drift.dart';
import '../../domain/entities/habit_experiment.dart';
import '../../domain/repositories/experiment_repository.dart';
import '../database/app_database.dart';
import '../mappers/experiment_mapper.dart';

/// Drift-backed implementation of [ExperimentRepository].
class DriftExperimentRepository implements ExperimentRepository {
  final AppDatabase _db;

  DriftExperimentRepository(this._db);

  // ---------------------------------------------------------------------------
  // Experiments
  // ---------------------------------------------------------------------------

  @override
  Future<HabitExperiment?> getExperimentById(String id) async {
    final query = _db.select(_db.habitExperiments)
      ..where((e) => e.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? ExperimentMapper.experimentToDomain(row) : null;
  }

  @override
  Future<List<HabitExperiment>> getAllExperiments() async {
    final query = _db.select(_db.habitExperiments)
      ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]);
    final rows = await query.get();
    return rows.map(ExperimentMapper.experimentToDomain).toList();
  }

  @override
  Future<List<HabitExperiment>> getExperimentsForHabit(
      String habitId) async {
    final query = _db.select(_db.habitExperiments)
      ..where((e) => e.habitId.equals(habitId))
      ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]);
    final rows = await query.get();
    return rows.map(ExperimentMapper.experimentToDomain).toList();
  }

  @override
  Future<List<HabitExperiment>> getActiveExperiments() async {
    // Status index 1 = active
    final activeIndex = ExperimentStatus.active.index;
    final query = _db.select(_db.habitExperiments)
      ..where((e) => e.status.equals(activeIndex))
      ..orderBy([(e) => OrderingTerm.asc(e.startDate)]);
    final rows = await query.get();
    return rows.map(ExperimentMapper.experimentToDomain).toList();
  }

  @override
  Future<void> insertExperiment(HabitExperiment experiment) async {
    await _db
        .into(_db.habitExperiments)
        .insert(ExperimentMapper.experimentToCompanion(experiment));
  }

  @override
  Future<void> updateExperiment(HabitExperiment experiment) async {
    await (_db.update(_db.habitExperiments)
          ..where((e) => e.id.equals(experiment.id)))
        .write(ExperimentMapper.experimentToCompanion(experiment));
  }

  @override
  Future<void> deleteExperiment(String id) async {
    await (_db.delete(_db.habitExperiments)..where((e) => e.id.equals(id)))
        .go();
  }

  @override
  Stream<List<HabitExperiment>> watchExperimentsForHabit(String habitId) {
    final query = _db.select(_db.habitExperiments)
      ..where((e) => e.habitId.equals(habitId))
      ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]);
    return query.watch().map(
          (rows) => rows.map(ExperimentMapper.experimentToDomain).toList(),
        );
  }

  @override
  Stream<List<HabitExperiment>> watchActiveExperiments() {
    final activeIndex = ExperimentStatus.active.index;
    final query = _db.select(_db.habitExperiments)
      ..where((e) => e.status.equals(activeIndex))
      ..orderBy([(e) => OrderingTerm.asc(e.startDate)]);
    return query.watch().map(
          (rows) => rows.map(ExperimentMapper.experimentToDomain).toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Observations
  // ---------------------------------------------------------------------------

  @override
  Future<ExperimentObservation?> getObservationById(String id) async {
    final query = _db.select(_db.experimentObservations)
      ..where((o) => o.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? ExperimentMapper.observationToDomain(row) : null;
  }

  @override
  Future<List<ExperimentObservation>> getObservationsForExperiment(
      String experimentId) async {
    final query = _db.select(_db.experimentObservations)
      ..where((o) => o.experimentId.equals(experimentId))
      ..orderBy([(o) => OrderingTerm.asc(o.date)]);
    final rows = await query.get();
    return rows.map(ExperimentMapper.observationToDomain).toList();
  }

  @override
  Future<ExperimentObservation?> getObservationForDate(
      String experimentId, DateTime date) async {
    final normalised = DateTime(date.year, date.month, date.day);
    final query = _db.select(_db.experimentObservations)
      ..where((o) =>
          o.experimentId.equals(experimentId) & o.date.equals(normalised));
    final row = await query.getSingleOrNull();
    return row != null ? ExperimentMapper.observationToDomain(row) : null;
  }

  @override
  Future<void> insertObservation(ExperimentObservation observation) async {
    await _db
        .into(_db.experimentObservations)
        .insert(ExperimentMapper.observationToCompanion(observation));
  }

  @override
  Future<void> updateObservation(ExperimentObservation observation) async {
    await (_db.update(_db.experimentObservations)
          ..where((o) => o.id.equals(observation.id)))
        .write(ExperimentMapper.observationToCompanion(observation));
  }

  @override
  Future<void> deleteObservation(String id) async {
    await (_db.delete(_db.experimentObservations)
          ..where((o) => o.id.equals(id)))
        .go();
  }

  @override
  Future<void> deleteObservationsForExperiment(String experimentId) async {
    await (_db.delete(_db.experimentObservations)
          ..where((o) => o.experimentId.equals(experimentId)))
        .go();
  }
}
