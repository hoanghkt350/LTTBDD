import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder_model.dart';
import 'health_appointments.dart';
import 'notification_plan.dart';

class NotificationService {
  static final instance = NotificationService._();
  NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;
  Future<void> _queue = Future.value();
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<void> initialize() => _initializing ??= _init();
  Future<void> _init() async {
    if (!supported) return;
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<void> replace(
    List<Reminder> reminders, {
    List<HealthAppointment> appointments = const [],
    bool requestPermission = false,
  }) {
    final next = _queue.catchError((Object _) {}).then((_) async {
      if (!supported) return;
      await initialize();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      final plan = buildNotificationPlan(
        reminders: reminders,
        appointments: appointments,
        now: tz.TZDateTime.now(tz.local),
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      // Cancel stale schedules even if permission was disabled in Settings.
      await _plugin.cancelAll();
      if (requestPermission && plan.isNotEmpty) {
        final allowed = await android?.requestNotificationsPermission();
        final ios = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        if (allowed == false || ios == false) {
          throw StateError(
            'Lịch đã lưu. Hãy bật quyền thông báo trong Cài đặt để nhận nhắc nhở.',
          );
        }
      }
      if (await android?.areNotificationsEnabled() == false &&
          plan.isNotEmpty) {
        throw StateError(
          'Thông báo đang tắt. Bật quyền thông báo trong Cài đặt của điện thoại.',
        );
      }
      // iOS keeps at most 64 pending notifications. Daily schedules occupy at
      // most 50 slots; fill the remainder with the nearest appointment alarms.
      final scheduled = defaultTargetPlatform == TargetPlatform.iOS
          ? plan.take(64)
          : plan;
      for (final notification in scheduled) {
        await _plugin.zonedSchedule(
          id: notification.id,
          title: 'PawPals nhắc bạn',
          body: notification.body,
          scheduledDate: notification.date,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'pet_care',
              'Chăm sóc thú cưng',
              channelDescription: 'Nhắc lịch chăm sóc, tiêm phòng và tái khám',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: notification.daily
              ? DateTimeComponents.time
              : null,
        );
      }
    });
    _queue = next;
    return next;
  }

  Future<void> clear() => replace([]);
}
