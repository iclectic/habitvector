import '../entities/habit_experiment.dart';

/// Abstract interface for experiment and observation data operations.
abstract class ExperimentRepository {
  // Experiments
  Future<HabitExperiment?> getExperimentById(String id);
  Future<List<HabitExperiment>> getAllExperiments();
  Future<List<HabitExperiment>> getExperimentsForHabit(String habitId);
  Future<List<HabitExperiment>> getActiveExperiments();
  Future<void> insertExperiment(HabitExperiment experiment);
  Future<void> updateExperiment(HabitExperiment experiment);
  Future<void> deleteExperiment(String id);
  Stream<List<HabitExperiment>> watchExperimentsForHabit(String habitId);
  Stream<List<HabitExperiment>> watchActiveExperiments();

  // Observations
  Future<ExperimentObservation?> getObservationById(String id);
  Future<List<ExperimentObservation>> getObservationsForExperiment(
      String experimentId);
  Future<ExperimentObservation?> getObservationForDate(
      String experimentId, DateTime date);
  Future<void> insertObservation(ExperimentObservation observation);
  Future<void> updateObservation(ExperimentObservation observation);
  Future<void> deleteObservation(String id);
  Future<void> deleteObservationsForExperiment(String experimentId);
}
