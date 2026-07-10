import 'package:drift/drift.dart';
import '../../domain/entities/habit_experiment.dart';
import '../../domain/entities/habit_versions.dart';
import '../database/app_database.dart';

/// Maps between domain [HabitExperiment] / [ExperimentObservation] and Drift rows.
class ExperimentMapper {
  static HabitExperiment experimentToDomain(HabitExperimentRow db) {
    return HabitExperiment(
      id: db.id,
      habitId: db.habitId,
      title: db.title,
      hypothesis: db.hypothesis,
      primaryOutcome: db.primaryOutcome,
      interventionA: db.interventionA,
      interventionB: db.interventionB,
      assignmentStrategy: AssignmentStrategy.values[db.assignmentStrategy],
      durationDays: db.durationDays,
      minimumObservations: db.minimumObservations,
      startDate: db.startDate,
      endDate: db.endDate,
      status: ExperimentStatus.values[db.status],
      confoundingNotes: db.confoundingNotes,
      resultSummary: db.resultSummary,
      createdAt: db.createdAt,
      updatedAt: db.updatedAt,
    );
  }

  static HabitExperimentsCompanion experimentToCompanion(
      HabitExperiment e) {
    return HabitExperimentsCompanion.insert(
      id: e.id,
      habitId: e.habitId,
      title: e.title,
      hypothesis: e.hypothesis,
      primaryOutcome: e.primaryOutcome,
      interventionA: e.interventionA,
      interventionB: e.interventionB,
      assignmentStrategy: e.assignmentStrategy.index,
      durationDays: e.durationDays,
      minimumObservations: e.minimumObservations,
      startDate: e.startDate,
      status: e.status.index,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    ).copyWith(
      endDate: e.endDate != null ? Value(e.endDate) : const Value(null),
      confoundingNotes: e.confoundingNotes != null
          ? Value(e.confoundingNotes)
          : const Value(null),
      resultSummary: e.resultSummary != null
          ? Value(e.resultSummary)
          : const Value(null),
    );
  }

  static ExperimentObservation observationToDomain(
      ExperimentObservationRow db) {
    return ExperimentObservation(
      id: db.id,
      experimentId: db.experimentId,
      habitId: db.habitId,
      date: db.date,
      assignment: InterventionAssignment.values[db.assignment],
      completed: db.completed,
      completedVersion: db.completedVersion != null
          ? HabitVersionLevel.values[db.completedVersion!]
          : null,
      checkInId: db.checkInId,
      shiftId: db.shiftId,
      createdAt: db.createdAt,
    );
  }

  static ExperimentObservationsCompanion observationToCompanion(
      ExperimentObservation o) {
    return ExperimentObservationsCompanion.insert(
      id: o.id,
      experimentId: o.experimentId,
      habitId: o.habitId,
      date: DateTime(o.date.year, o.date.month, o.date.day),
      assignment: o.assignment.index,
      completed: o.completed,
      createdAt: o.createdAt,
    ).copyWith(
      completedVersion: o.completedVersion != null
          ? Value(o.completedVersion!.index)
          : const Value(null),
      checkInId:
          o.checkInId != null ? Value(o.checkInId) : const Value(null),
      shiftId: o.shiftId != null ? Value(o.shiftId) : const Value(null),
    );
  }
}
