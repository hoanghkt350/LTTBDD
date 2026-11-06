import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder_model.dart';

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
    bool requestPermission = false,
  }) {
    final next = _queue.catchError((Object _) {}).then((_) async {
      if (!supported) return;
      await initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (requestPermission) {
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
          reminders.any((r) => r.isActive == 1)) {
        throw StateError(
          'Thông báo đang tắt. Bật quyền thông báo trong Cài đặt của điện thoại.',
        );
      }
      await _plugin.cancelAll();
      for (final reminder in reminders.where((r) => r.isActive == 1)) {
        final time = reminder.reminderTime.split(':');
        final now = tz.TZDateTime.now(tz.local);
        var nextTime = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          int.parse(time[0]),
          int.parse(time[1]),
        );
        if (!nextTime.isAfter(now)) {
          nextTime = tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day + 1,
            int.parse(time[0]),
            int.parse(time[1]),
          );
        }
        await _plugin.zonedSchedule(
          id: reminder.notificationId,
          title: 'PawPals nhắc bạn',
          body: reminder.title,
          scheduledDate: nextTime,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'pet_care',
              'Chăm sóc thú cưng',
              channelDescription: 'Nhắc lịch chăm sóc hàng ngày',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    });
    _queue = next;
    return next;
  }

  Future<void> clear() => replace([]);
}
