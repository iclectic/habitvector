import 'habit_versions.dart';

/// Assignment strategy for allocating observations between interventions.
enum AssignmentStrategy {
  randomised,
  alternating,
}

/// Current lifecycle state of an experiment.
enum ExperimentStatus {
  draft,
  active,
  paused,
  completed,
  cancelled,
}

/// A structured personal experiment comparing two habit strategies.
///
/// The user defines a clear hypothesis, two interventions, a duration,
/// and a minimum sample size. The engine assigns each observation to
/// intervention A or B. Results are analysed once the experiment ends.
///
/// Causal language is avoided. Results use qualified observational wording.
class HabitExperiment {
  final String id;
  final String habitId;
  final String title;
  final String hypothesis;

  /// What outcome is being measured (e.g. "completion rate").
  final String primaryOutcome;

  /// Description of intervention A.
  final String interventionA;

  /// Description of intervention B.
  final String interventionB;

  final AssignmentStrategy assignmentStrategy;
  final int durationDays;
  final int minimumObservations;
  final DateTime startDate;
  final DateTime? endDate;
  final ExperimentStatus status;

  /// User-noted potential confounders (e.g. started new job during experiment).
  final String? confoundingNotes;

  /// Summary of results — populated when status becomes [ExperimentStatus.completed].
  final String? resultSummary;

  final DateTime createdAt;
  final DateTime updatedAt;

  const HabitExperiment({
    required this.id,
    required this.habitId,
    required this.title,
    required this.hypothesis,
    required this.primaryOutcome,
    required this.interventionA,
    required this.interventionB,
    required this.assignmentStrategy,
    required this.durationDays,
    required this.minimumObservations,
    required this.startDate,
    this.endDate,
    required this.status,
    this.confoundingNotes,
    this.resultSummary,
    required this.createdAt,
    required this.updatedAt,
  });

  DateTime get scheduledEndDate =>
      startDate.add(Duration(days: durationDays));

  HabitExperiment copyWith({
    String? id,
    String? habitId,
    String? title,
    String? hypothesis,
    String? primaryOutcome,
    String? interventionA,
    String? interventionB,
    AssignmentStrategy? assignmentStrategy,
    int? durationDays,
    int? minimumObservations,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    ExperimentStatus? status,
    String? confoundingNotes,
    bool clearConfoundingNotes = false,
    String? resultSummary,
    bool clearResultSummary = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitExperiment(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      title: title ?? this.title,
      hypothesis: hypothesis ?? this.hypothesis,
      primaryOutcome: primaryOutcome ?? this.primaryOutcome,
      interventionA: interventionA ?? this.interventionA,
      interventionB: interventionB ?? this.interventionB,
      assignmentStrategy: assignmentStrategy ?? this.assignmentStrategy,
      durationDays: durationDays ?? this.durationDays,
      minimumObservations: minimumObservations ?? this.minimumObservations,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      status: status ?? this.status,
      confoundingNotes: clearConfoundingNotes
          ? null
          : (confoundingNotes ?? this.confoundingNotes),
      resultSummary:
          clearResultSummary ? null : (resultSummary ?? this.resultSummary),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitExperiment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Which intervention was assigned for a single observation.
enum InterventionAssignment { a, b }

/// A single observation within an experiment.
///
/// Records which intervention was applied, whether the habit was completed,
/// and any context available at the time.
class ExperimentObservation {
  final String id;
  final String experimentId;
  final String habitId;
  final DateTime date;
  final InterventionAssignment assignment;
  final bool completed;
  final HabitVersionLevel? completedVersion;

  /// Optional reference to the daily check-in for that day.
  final String? checkInId;

  /// Optional reference to a work shift active that day.
  final String? shiftId;

  final DateTime createdAt;

  const ExperimentObservation({
    required this.id,
    required this.experimentId,
    required this.habitId,
    required this.date,
    required this.assignment,
    required this.completed,
    this.completedVersion,
    this.checkInId,
    this.shiftId,
    required this.createdAt,
  });

  DateTime get normalisedDate => DateTime(date.year, date.month, date.day);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExperimentObservation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
