import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// Habits table definition.
@DataClassName('HabitRow')
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  IntColumn get colourValue => integer()();
  IntColumn get iconCodePoint => integer()();
  TextColumn get iconFontFamily => text().withDefault(const Constant('MaterialIcons'))();
  IntColumn get scheduleType => integer()();
  TextColumn get scheduledDays => text().withDefault(const Constant('[]'))();
  IntColumn get customFrequencyPerWeek => integer().withDefault(const Constant(1))();
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

@DriftDatabase(tables: [Habits, HabitLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with a provided executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future migrations here
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
