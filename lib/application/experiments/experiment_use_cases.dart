import 'package:uuid/uuid.dart';

import '../../domain/entities/habit_experiment.dart';
import '../../domain/repositories/experiment_repository.dart';
import '../../domain/services/clock.dart';
import 'assignment_engine.dart';
import 'experiment_analyser.dart';

/// Use cases for the N-of-1 experiment lifecycle.
///
/// Lifecycle: draft → active → (paused ↔ active) → completed | cancelled
///
/// Rules:
/// - Only one active experiment per habit at a time.
/// - Observations can only be recorded for active experiments.
/// - Completing an experiment runs [ExperimentAnalyser] and stores a summary.
/// - Cancelling preserves existing observations for historical review.
class ExperimentUseCases {
  final ExperimentRepository _repo;
  final AssignmentEngine _assignmentEngine;
  final ExperimentAnalyser _analyser;
  final Clock _clock;
  final Uuid _uuid;

  ExperimentUseCases({
    required ExperimentRepository repo,
    AssignmentEngine assignmentEngine = const AssignmentEngine(),
    ExperimentAnalyser analyser = const ExperimentAnalyser(),
    Clock clock = const SystemClock(),
    Uuid? uuid,
  })  : _repo = repo,
        _assignmentEngine = assignmentEngine,
        _analyser = analyser,
        _clock = clock,
        _uuid = uuid ?? const Uuid();

  // ---------------------------------------------------------------------------
  // Experiment lifecycle
  // ---------------------------------------------------------------------------

  /// Create a new experiment in draft state. Does NOT start it.
  ///
  /// Throws [StateError] if there is already an active experiment for the same
  /// habit — only one active experiment per habit is allowed.
  Future<HabitExperiment> createExperiment({
    required String habitId,
    required String title,
    required String hypothesis,
    required String primaryOutcome,
    required String interventionA,
    required String interventionB,
    required AssignmentStrategy assignmentStrategy,
    required int durationDays,
    required int minimumObservations,
  }) async {
    if (durationDays < 1) {
      throw ArgumentError.value(durationDays, 'durationDays', 'Must be ≥ 1');
    }
    if (minimumObservations < 2) {
      throw ArgumentError.value(
          minimumObservations, 'minimumObservations', 'Must be ≥ 2');
    }

    final existing = await _repo.getActiveExperiments();
    if (existing.any((e) => e.habitId == habitId)) {
      throw StateError(
          'Habit $habitId already has an active experiment. '
          'Complete or cancel it before creating a new one.');
    }

    final now = _clock.now();
    final experiment = HabitExperiment(
      id: _uuid.v4(),
      habitId: habitId,
      title: title,
      hypothesis: hypothesis,
      primaryOutcome: primaryOutcome,
      interventionA: interventionA,
      interventionB: interventionB,
      assignmentStrategy: assignmentStrategy,
      durationDays: durationDays,
      minimumObservations: minimumObservations,
      startDate: now,
      status: ExperimentStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.insertExperiment(experiment);
    return experiment;
  }

  /// Transition a draft experiment to active.
  ///
  /// Throws [StateError] if the experiment is not in draft state.
  Future<HabitExperiment> startExperiment(String experimentId) async {
    final experiment = await _requireExperiment(experimentId);
    if (experiment.status != ExperimentStatus.draft) {
      throw StateError(
          'Can only start a draft experiment. '
          'Current status: ${experiment.status.name}');
    }
    final now = _clock.now();
    final updated = experiment.copyWith(
      status: ExperimentStatus.active,
      startDate: now,
      updatedAt: now,
    );
    await _repo.updateExperiment(updated);
    return updated;
  }

  /// Pause an active experiment. Observations are preserved.
  Future<HabitExperiment> pauseExperiment(String experimentId) async {
    final experiment = await _requireExperiment(experimentId);
    _requireStatus(experiment, ExperimentStatus.active, 'pause');
    final updated = experiment.copyWith(
      status: ExperimentStatus.paused,
      updatedAt: _clock.now(),
    );
    await _repo.updateExperiment(updated);
    return updated;
  }

  /// Resume a paused experiment.
  Future<HabitExperiment> resumeExperiment(String experimentId) async {
    final experiment = await _requireExperiment(experimentId);
    _requireStatus(experiment, ExperimentStatus.paused, 'resume');
    final updated = experiment.copyWith(
      status: ExperimentStatus.active,
      updatedAt: _clock.now(),
    );
    await _repo.updateExperiment(updated);
    return updated;
  }

  /// Complete an experiment, analyse results, and store the summary.
  ///
  /// Can be called on active or paused experiments.
  Future<HabitExperiment> completeExperiment(String experimentId) async {
    final experiment = await _requireExperiment(experimentId);
    if (experiment.status != ExperimentStatus.active &&
        experiment.status != ExperimentStatus.paused) {
      throw StateError(
          'Can only complete an active or paused experiment. '
          'Current status: ${experiment.status.name}');
    }

    final observations =
        await _repo.getObservationsForExperiment(experimentId);
    final analysis = _analyser.analyse(
        experiment: experiment, observations: observations);

    final now = _clock.now();
    final updated = experiment.copyWith(
      status: ExperimentStatus.completed,
      endDate: now,
      resultSummary: analysis.conclusion,
      updatedAt: now,
    );
    await _repo.updateExperiment(updated);
    return updated;
  }

  /// Cancel an experiment. Observations are retained for historical review.
  Future<HabitExperiment> cancelExperiment(String experimentId) async {
    final experiment = await _requireExperiment(experimentId);
    if (experiment.status == ExperimentStatus.completed ||
        experiment.status == ExperimentStatus.cancelled) {
      throw StateError(
          'Cannot cancel a ${experiment.status.name} experiment.');
    }
    final now = _clock.now();
    final updated = experiment.copyWith(
      status: ExperimentStatus.cancelled,
      endDate: now,
      updatedAt: now,
    );
    await _repo.updateExperiment(updated);
    return updated;
  }

  /// Add a confounding note to an experiment (e.g. "started new job").
  Future<HabitExperiment> addConfoundingNote(
      String experimentId, String note) async {
    final experiment = await _requireExperiment(experimentId);
    final updated = experiment.copyWith(
      confoundingNotes: note,
      updatedAt: _clock.now(),
    );
    await _repo.updateExperiment(updated);
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Observation recording
  // ---------------------------------------------------------------------------

  /// Record an observation for an active experiment.
  ///
  /// Arm assignment is determined automatically by [AssignmentEngine].
  /// Throws [StateError] if the experiment is not active.
  /// Throws [StateError] if an observation already exists for [date].
  Future<ExperimentObservation> recordObservation({
    required String experimentId,
    required bool completed,
    DateTime? date,
    String? checkInId,
    String? shiftId,
  }) async {
    final experiment = await _requireExperiment(experimentId);
    _requireStatus(experiment, ExperimentStatus.active, 'record observations for');

    final observationDate = _normalise(date ?? _clock.today());
    final existing =
        await _repo.getObservationForDate(experimentId, observationDate);
    if (existing != null) {
      throw StateError(
          'An observation already exists for $experimentId on $observationDate. '
          'Update the existing observation instead.');
    }

    final allObs = await _repo.getObservationsForExperiment(experimentId);
    final assignment = _assignmentEngine.assign(
      experiment: experiment,
      existingCount: allObs.length,
    );

    final observation = ExperimentObservation(
      id: _uuid.v4(),
      experimentId: experimentId,
      habitId: experiment.habitId,
      date: observationDate,
      assignment: assignment,
      completed: completed,
      checkInId: checkInId,
      shiftId: shiftId,
      createdAt: _clock.now(),
    );
    await _repo.insertObservation(observation);
    return observation;
  }

  /// Retrieve the current analysis snapshot for an experiment.
  ///
  /// Can be called at any time — returns [EvidenceStrength.insufficient]
  /// when not enough observations exist.
  Future<ExperimentAnalysis> getAnalysis(String experimentId) async {
    final experiment = await _requireExperiment(experimentId);
    final observations =
        await _repo.getObservationsForExperiment(experimentId);
    return _analyser.analyse(
        experiment: experiment, observations: observations);
  }

  /// Get the next arm assignment without recording an observation.
  ///
  /// Used by the UI to show users which intervention applies today.
  Future<InterventionAssignment> peekNextAssignment(
      String experimentId) async {
    final experiment = await _requireExperiment(experimentId);
    final allObs = await _repo.getObservationsForExperiment(experimentId);
    return _assignmentEngine.assign(
      experiment: experiment,
      existingCount: allObs.length,
    );
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  Future<List<HabitExperiment>> getActiveExperiments() =>
      _repo.getActiveExperiments();

  Future<List<HabitExperiment>> getExperimentsForHabit(String habitId) =>
      _repo.getExperimentsForHabit(habitId);

  Stream<List<HabitExperiment>> watchActiveExperiments() =>
      _repo.watchActiveExperiments();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<HabitExperiment> _requireExperiment(String id) async {
    final e = await _repo.getExperimentById(id);
    if (e == null) throw StateError('Experiment $id not found.');
    return e;
  }

  void _requireStatus(
      HabitExperiment experiment, ExperimentStatus required, String verb) {
    if (experiment.status != required) {
      throw StateError(
          'Can only $verb an ${required.name} experiment. '
          'Current status: ${experiment.status.name}');
    }
  }

  DateTime _normalise(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
