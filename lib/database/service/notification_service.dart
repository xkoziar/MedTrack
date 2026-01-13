import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/user_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

const String _lastScheduleKey = 'last_notification_schedule';
const int _scheduleDaysAhead = 7;
const int _rescheduleThresholdDays = 4;

class NotificationService {
  NotificationService._();

  static final _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);

    const androidChannel = AndroidNotificationChannel(
      'medication_reminders',
      'Medication Reminders',
      description: 'Reminders for medication doses',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(androidChannel);

    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      final notifGranted = await android.requestNotificationsPermission();
      final exactAlarmGranted = await android.requestExactAlarmsPermission();
      return (notifGranted ?? false) && (exactAlarmGranted ?? true);
    }
    return true;
  }

  static Future<bool> canScheduleExactAlarms() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.canScheduleExactNotifications() ?? false;
    }
    return true;
  }

  static Future<void> reschedule() async {
    try {
      final auth = get<AuthService>();
      final userId = auth.user?.uid;
      if (userId == null) return;

      final userService = get<UserDatabaseService>();
      final user = await userService.get(userId);
      if (user == null || !user.notificationsEnabled) return;

      await scheduleForUser(userId, user.reminderMinutes);
    } catch (_) {}
  }

  static Future<void> checkAndExtendWindow() async {
    try {
      final auth = get<AuthService>();
      final userId = auth.user?.uid;
      if (userId == null) return;

      final userService = get<UserDatabaseService>();
      final user = await userService.get(userId);
      if (user == null || !user.notificationsEnabled) return;

      final prefs = await SharedPreferences.getInstance();
      final lastScheduleTime = prefs.getInt('${_lastScheduleKey}_$userId');

      if (lastScheduleTime == null) {
        await scheduleForUser(userId, user.reminderMinutes);
        return;
      }

      final lastSchedule =
          DateTime.fromMillisecondsSinceEpoch(lastScheduleTime);
      final daysSince = DateTime.now().difference(lastSchedule).inDays;

      if (daysSince >= _rescheduleThresholdDays) {
        await scheduleForUser(userId, user.reminderMinutes);
      }
    } catch (_) {}
  }

  static Future<void> scheduleForUser(
    String userId,
    int reminderMinutes,
  ) async {
    if (!await canScheduleExactAlarms()) return;

    await cancelAll();

    if (reminderMinutes < 0) return;

    final medService = get<MedicationDatabaseService>();
    final medications = await medService.getUserMedications(userId);
    final activeMeds = medications.where((m) => m.isActive).toList();

    for (final med in activeMeds) {
      await _scheduleMedicationNotifications(med, reminderMinutes);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '${_lastScheduleKey}_$userId',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<void> _scheduleMedicationNotifications(
    Medication med,
    int reminderMinutes,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDateOnly = DateTime(
      med.startDate.year,
      med.startDate.month,
      med.startDate.day,
    );

    for (int dayOffset = 0; dayOffset < _scheduleDaysAhead; dayOffset++) {
      final date = today.add(Duration(days: dayOffset));

      if (!med.scheduleDays.contains(date.weekday)) continue;
      if (date.isBefore(startDateOnly)) continue;

      for (final timeStr in med.scheduleTimes) {
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        final dosageTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );

        if (dosageTime.isBefore(now)) continue;

        var notifyTime = dosageTime.subtract(
          Duration(minutes: reminderMinutes),
        );

        if (notifyTime.isBefore(now)) {
          notifyTime = now.add(const Duration(seconds: 10));
        }

        final id = _generateNotificationId(med.id, date, timeStr);
        final title = 'Time for ${med.name}';
        final body = reminderMinutes > 0
            ? 'Due in $reminderMinutes minutes'
            : 'Take your medication now';

        await _notifications.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(notifyTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'medication_reminders',
              'Medication Reminders',
              channelDescription: 'Reminders for medication doses',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              category: AndroidNotificationCategory.alarm,
              visibility: NotificationVisibility.public,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }

  static int _generateNotificationId(String medId, DateTime date, String time) {
    final hash = '${medId}_${date.day}_${date.month}_$time'.hashCode;
    return hash.abs() % 2147483647;
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
