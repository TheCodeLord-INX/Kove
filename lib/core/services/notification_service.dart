import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles local push notifications for the Tenant Manager app.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Must be called once at app startup (and again inside background isolates).
  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: initSettings);

    // Create the high-importance notification channel
    const channel = AndroidNotificationChannel(
      'audit_reminders',
      'Audit Reminders',
      description: 'Monthly meter audit and pending room alerts',
      importance: Importance.high,
      playSound: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Push a notification alerting about missing meter readings.
  static Future<void> showAuditReminder(int missingCount) async {
    const androidDetails = AndroidNotificationDetails(
      'audit_reminders',
      'Audit Reminders',
      channelDescription: 'Monthly meter audit and pending room alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: 25, // notification ID for audit day
      title: 'Meter Audit Day! 🔌',
      body: 'You have $missingCount room${missingCount == 1 ? '' : 's'} '
          "pending for today's grid sync.",
      notificationDetails: details,
    );
  }
}
