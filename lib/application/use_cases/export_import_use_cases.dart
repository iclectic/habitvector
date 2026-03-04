import 'dart:convert';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../domain/repositories/habit_log_repository.dart';

/// Data transfer object for export/import.
class ExportData {
  final List<Habit> habits;
  final List<HabitLog> logs;
  final DateTime exportedAt;
  final String version;

  const ExportData({
    required this.habits,
    required this.logs,
    required this.exportedAt,
    this.version = '1.0.0',
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'habits': habits.map((h) => h.toJson()).toList(),
      'logs': logs.map((l) => l.toJson()).toList(),
    };
  }

  factory ExportData.fromJson(Map<String, dynamic> json) {
    return ExportData(
      version: json['version'] as String? ?? '1.0.0',
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      habits: (json['habits'] as List<dynamic>)
          .map((h) => Habit.fromJson(h as Map<String, dynamic>))
          .toList(),
      logs: (json['logs'] as List<dynamic>)
          .map((l) => HabitLog.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Validation result for import operations.
class ImportValidation {
  final bool isValid;
  final List<String> errors;
  final ExportData? data;

  const ImportValidation({
    required this.isValid,
    this.errors = const [],
    this.data,
  });
}

/// Use cases for data export and import.
class ExportImportUseCases {
  final HabitRepository _habitRepository;
  final HabitLogRepository _logRepository;

  ExportImportUseCases(this._habitRepository, this._logRepository);

  /// Export all habits and logs to JSON string.
  Future<String> exportToJson() async {
    final habits = await _habitRepository.getAllHabits();
    final logs = <HabitLog>[];
    for (final habit in habits) {
      final habitLogs = await _logRepository.getLogsForHabit(habit.id);
      logs.addAll(habitLogs);
    }

    final exportData = ExportData(
      habits: habits,
      logs: logs,
      exportedAt: DateTime.now(),
    );

    return const JsonEncoder.withIndent('  ').convert(exportData.toJson());
  }

  /// Validate JSON string before import.
  ImportValidation validateJson(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      final errors = <String>[];

      if (!json.containsKey('habits')) {
        errors.add('Missing "habits" field.');
      }
      if (!json.containsKey('logs')) {
        errors.add('Missing "logs" field.');
      }
      if (!json.containsKey('exportedAt')) {
        errors.add('Missing "exportedAt" field.');
      }

      if (errors.isNotEmpty) {
        return ImportValidation(isValid: false, errors: errors);
      }

      final data = ExportData.fromJson(json);

      // Validate habits have required fields
      for (final habit in data.habits) {
        if (habit.id.isEmpty) {
          errors.add('Habit with empty ID found.');
        }
        if (habit.title.isEmpty) {
          errors.add('Habit with empty title found.');
        }
      }

      // Validate logs reference existing habits
      final habitIds = data.habits.map((h) => h.id).toSet();
      for (final log in data.logs) {
        if (!habitIds.contains(log.habitId)) {
          errors.add(
              'Log ${log.id} references non-existent habit ${log.habitId}.');
        }
      }

      if (errors.isNotEmpty) {
        return ImportValidation(isValid: false, errors: errors);
      }

      return ImportValidation(isValid: true, data: data);
    } catch (e) {
      return ImportValidation(
        isValid: false,
        errors: ['Invalid JSON format: ${e.toString()}'],
      );
    }
  }

  /// Import habits and logs from validated export data.
  /// Existing habits with the same ID will be overwritten.
  Future<void> importFromJson(String jsonString) async {
    final validation = validateJson(jsonString);
    if (!validation.isValid || validation.data == null) {
      throw Exception(
          'Invalid import data: ${validation.errors.join(', ')}');
    }

    final data = validation.data!;

    for (final habit in data.habits) {
      final existing = await _habitRepository.getHabitById(habit.id);
      if (existing != null) {
        await _habitRepository.updateHabit(habit);
      } else {
        await _habitRepository.insertHabit(habit);
      }
    }

    for (final log in data.logs) {
      final existing =
          await _logRepository.getLogForHabitOnDate(log.habitId, log.date);
      if (existing != null) {
        await _logRepository.updateLog(log);
      } else {
        await _logRepository.insertLog(log);
      }
    }
  }
}
