import '../entities/work_shift.dart';

/// Abstract interface for work shift data operations.
abstract class ShiftRepository {
  Future<List<WorkShift>> getAllShifts();
  Future<List<WorkShift>> getActiveShifts();
  Future<List<WorkShift>> getShiftsForDate(DateTime date);
  Future<List<WorkShift>> getShiftsInRange(DateTime start, DateTime end);
  Future<WorkShift?> getShiftById(String id);
  Future<void> insertShift(WorkShift shift);
  Future<void> updateShift(WorkShift shift);
  Future<void> deleteShift(String id);
  Future<void> archiveShift(String id);
  Stream<List<WorkShift>> watchShiftsForDate(DateTime date);
  Stream<List<WorkShift>> watchActiveShifts();
}
