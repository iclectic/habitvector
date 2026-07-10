import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// v1 tables — NEVER modified structurally after release
// ---------------------------------------------------------------------------

/// Habits table definition.
@DataClassName('HabitRow')
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  IntColumn get colourValue => integer()();
  IntColumn get iconCodePoint => integer()();
  TextColumn get iconFontFamily =>
      text().withDefault(const Constant('MaterialIcons'))();
  IntColumn get scheduleType => integer()();
  TextColumn get scheduledDays => text().withDefault(const Constant('[]'))();
  IntColumn get customFrequencyPerWeek =>
      integer().withDefault(const Constant(1))();
  IntColumn get goalType => integer()();
  RealColumn get targetQuantity => real().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get reminderTimes => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Habit logs table definition.
@DataClassName('HabitLogRow')
class HabitLogs extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();
  DateTimeColumn get date => dateTime()();
  BoolColumn get completed => boolean()();
  RealColumn get value => real().nullable()();
  BoolColumn get skipped => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// v2 tables — added Phase 1, purely additive
// ---------------------------------------------------------------------------

/// Daily context check-in (all fields optional from the user's perspective).
@DataClassName('DailyCheckInRow')
class DailyCheckIns extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();

  /// Available time in minutes.
  IntColumn get availableMinutes => integer().nullable()();

  /// EnergyLevel enum index (0–4). Null if not provided.
  IntColumn get energyLevel => integer().nullable()();

  /// WorkloadLevel enum index (0–3). Null if not provided.
  IntColumn get workloadLevel => integer().nullable()();

  /// DayType enum index (0–4). Null if not provided.
  IntColumn get dayType => integer().nullable()();

  /// Free-text shift label (e.g. "Night shift"). Null if not provided.
  TextColumn get shiftLabel => text().nullable()();

  /// ChallengePreference enum index (0–2). Null if not provided.
  IntColumn get challengePreference => integer().nullable()();

  /// User self-reported confidence 0.0–1.0. Null if not provided.
  RealColumn get confidenceScore => real().nullable()();

  /// Free-text notes. Stored locally only, never sent externally.
  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Work shift entries.
@DataClassName('WorkShiftRow')
class WorkShifts extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  BoolColumn get isOvernight => boolean().withDefault(const Constant(false))();

  /// ShiftRecurrence enum index.
  IntColumn get recurrence => integer().withDefault(const Constant(0))();

  /// JSON-encoded list of ISO weekday ints for weekly recurrence.
  TextColumn get recurrenceWeekdays =>
      text().withDefault(const Constant('[]'))();

  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Three-level version definitions (min/standard/stretch) per habit.
@DataClassName('HabitVersionsRow')
class HabitVersionsTable extends Table {
  @override
  String get tableName => 'habit_versions';

  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();
  TextColumn get minimumDescription => text().nullable()();
  IntColumn get minimumDurationMinutes => integer().nullable()();
  TextColumn get standardDescription => text().nullable()();
  IntColumn get standardDurationMinutes => integer().nullable()();
  TextColumn get stretchDescription => text().nullable()();
  IntColumn get stretchDurationMinutes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Adaptive recommendations produced by the recommendation engine.
@DataClassName('AdaptiveRecommendationRow')
class AdaptiveRecommendations extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();
  DateTimeColumn get generatedAt => dateTime()();
  DateTimeColumn get forDate => dateTime()();

  /// RecommendedAction enum index.
  IntColumn get action => integer()();

  /// HabitVersionLevel enum index. Null if not version-specific.
  IntColumn get suggestedVersion => integer().nullable()();

  /// 0.0–1.0.
  RealColumn get confidence => real()();

  TextColumn get explanation => text()();

  /// JSON-encoded list of factor strings.
  TextColumn get factorsUsed => text().withDefault(const Constant('[]'))();

  /// JSON-encoded list of missing factor strings.
  TextColumn get factorsMissing => text().withDefault(const Constant('[]'))();

  /// RecommendedAction enum index for the alternative.
  IntColumn get alternativeAction => integer()();

  TextColumn get modelVersion => text()();

  /// RecommendationSource enum index.
  IntColumn get source => integer()();

  /// RecommendationFeedback enum index. Null before user responds.
  IntColumn get feedback => integer().nullable()();
  DateTimeColumn get feedbackAt => dateTime().nullable()();
  TextColumn get feedbackNote => text().nullable()();

  BoolColumn get completed => boolean().nullable()();
  IntColumn get completedVersion => integer().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Habit experiments (N-of-1 design).
@DataClassName('HabitExperimentRow')
class HabitExperiments extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();
  TextColumn get title => text()();
  TextColumn get hypothesis => text()();
  TextColumn get primaryOutcome => text()();
  TextColumn get interventionA => text()();
  TextColumn get interventionB => text()();

  /// AssignmentStrategy enum index.
  IntColumn get assignmentStrategy => integer()();

  IntColumn get durationDays => integer()();
  IntColumn get minimumObservations => integer()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();

  /// ExperimentStatus enum index.
  IntColumn get status => integer()();

  TextColumn get confoundingNotes => text().nullable()();
  TextColumn get resultSummary => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Individual observations within an experiment.
@DataClassName('ExperimentObservationRow')
class ExperimentObservations extends Table {
  TextColumn get id => text()();
  TextColumn get experimentId =>
      text().references(HabitExperiments, #id)();
  TextColumn get habitId => text().references(Habits, #id)();
  DateTimeColumn get date => dateTime()();

  /// InterventionAssignment enum index (0=a, 1=b).
  IntColumn get assignment => integer()();

  BoolColumn get completed => boolean()();

  /// HabitVersionLevel enum index. Null if not recorded.
  IntColumn get completedVersion => integer().nullable()();

  TextColumn get checkInId => text().nullable()();
  TextColumn get shiftId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Model metadata — stores the version and serialised parameters of the
/// current recommendation model per habit.
@DataClassName('ModelMetadataRow')
class ModelMetadata extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();
  TextColumn get modelVersion => text()();
  TextColumn get source => text()();

  /// JSON-serialised model parameters (e.g. Bayesian priors).
  TextColumn get parameters => text().withDefault(const Constant('{}'))();

  IntColumn get observationCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [
  Habits,
  HabitLogs,
  DailyCheckIns,
  WorkShifts,
  HabitVersionsTable,
  AdaptiveRecommendations,
  HabitExperiments,
  ExperimentObservations,
  ModelMetadata,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with a provided executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // v1 → v2: add all new tables (purely additive, no existing columns changed)
        if (from < 2) {
          await m.createTable(dailyCheckIns);
          await m.createTable(workShifts);
          await m.createTable(habitVersionsTable);
          await m.createTable(adaptiveRecommendations);
          await m.createTable(habitExperiments);
          await m.createTable(experimentObservations);
          await m.createTable(modelMetadata);
        }
      },
      beforeOpen: (details) async {
        // Enable foreign key enforcement.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'habit_flow.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
