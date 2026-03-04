import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../../domain/entities/habit.dart';

/// Service for managing local notifications with timezone-safe scheduling.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  /// Initialise the notification service.
  Future<void> initialise() async {
    if (_initialised) return;

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _initialised = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap - can be extended with navigation
  }

  /// Request notification permissions.
  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final result = await androidPlugin?.requestNotificationsPermission();
      return result ?? false;
    }
    return false;
  }

  /// Schedule notifications for a habit based on its reminder times.
  Future<void> scheduleHabitReminders(Habit habit) async {
    // Cancel existing notifications for this habit first
    await cancelHabitReminders(habit.id);

    if (habit.reminderTimes.isEmpty || habit.archived) return;

    for (int i = 0; i < habit.reminderTimes.length; i++) {
      final time = habit.reminderTimes[i];
      final notificationId = _generateNotificationId(habit.id, i);

      await _scheduleDaily(
        id: notificationId,
        title: 'Habit Vector Reminder',
        body: 'Time to complete: ${habit.title}',
        time: time,
        habitColour: Color(habit.colourValue),
      );
    }
  }

  /// Schedule a daily notification at a specific time.
  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    Color? habitColour,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Reminders for your daily habits',
      importance: Importance.high,
      priority: Priority.high,
      color: habitColour,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancel all notifications for a habit.
  Future<void> cancelHabitReminders(String habitId) async {
    // Cancel up to 10 possible reminder slots per habit
    for (int i = 0; i < 10; i++) {
      final notificationId = _generateNotificationId(habitId, i);
      await _plugin.cancel(notificationId);
    }
  }

  /// Cancel all notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Send a test notification immediately.
  Future<void> sendTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Reminders for your daily habits',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      0,
      'Habit Vector Test',
      'Notifications are working correctly!',
      details,
    );
  }

  /// Get pending notifications.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }

  /// Generate a deterministic notification ID from habit ID and index.
  int _generateNotificationId(String habitId, int index) {
    return (habitId.hashCode + index) & 0x7FFFFFFF;
  }
}
