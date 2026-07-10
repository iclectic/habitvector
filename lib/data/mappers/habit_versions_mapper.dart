import 'package:drift/drift.dart';
import '../../domain/entities/habit_versions.dart';
import '../database/app_database.dart';

/// Maps between domain [HabitVersions] and Drift [HabitVersionsRow].
class HabitVersionsMapper {
  static HabitVersions toDomain(HabitVersionsRow db) {
    return HabitVersions(
      id: db.id,
      habitId: db.habitId,
      minimumDescription: db.minimumDescription,
      minimumDurationMinutes: db.minimumDurationMinutes,
      standardDescription: db.standardDescription,
      standardDurationMinutes: db.standardDurationMinutes,
      stretchDescription: db.stretchDescription,
      stretchDurationMinutes: db.stretchDurationMinutes,
      createdAt: db.createdAt,
      updatedAt: db.updatedAt,
    );
  }

  static HabitVersionsTableCompanion toCompanion(HabitVersions v) {
    return HabitVersionsTableCompanion.insert(
      id: v.id,
      habitId: v.habitId,
      createdAt: v.createdAt,
      updatedAt: v.updatedAt,
    ).copyWith(
      minimumDescription: v.minimumDescription != null
          ? Value(v.minimumDescription)
          : const Value(null),
      minimumDurationMinutes: v.minimumDurationMinutes != null
          ? Value(v.minimumDurationMinutes)
          : const Value(null),
      standardDescription: v.standardDescription != null
          ? Value(v.standardDescription)
          : const Value(null),
      standardDurationMinutes: v.standardDurationMinutes != null
          ? Value(v.standardDurationMinutes)
          : const Value(null),
      stretchDescription: v.stretchDescription != null
          ? Value(v.stretchDescription)
          : const Value(null),
      stretchDurationMinutes: v.stretchDurationMinutes != null
          ? Value(v.stretchDurationMinutes)
          : const Value(null),
    );
  }
}
