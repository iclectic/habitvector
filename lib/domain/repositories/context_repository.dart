import '../entities/daily_check_in.dart';

/// Abstract interface for daily context check-in data operations.
abstract class ContextRepository {
  Future<DailyCheckIn?> getCheckInForDate(DateTime date);
  Future<List<DailyCheckIn>> getCheckInsInRange(DateTime start, DateTime end);
  Future<List<DailyCheckIn>> getAllCheckIns();
  Future<void> insertCheckIn(DailyCheckIn checkIn);
  Future<void> updateCheckIn(DailyCheckIn checkIn);
  Future<void> deleteCheckIn(String id);
  Stream<DailyCheckIn?> watchCheckInForDate(DateTime date);
}
