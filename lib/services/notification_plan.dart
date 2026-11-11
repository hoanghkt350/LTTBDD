import 'package:timezone/timezone.dart' as tz;

import '../models/reminder_model.dart';
import 'health_appointments.dart';

class PetNotification {
  const PetNotification({
    required this.id,
    required this.body,
    required this.date,
    this.daily = false,
  });
  final int id;
  final String body;
  final tz.TZDateTime date;
  final bool daily;
}

/// Builds one shared plan so daily reminders and appointments cannot overwrite
/// each other's notification IDs. Replacing a plan cancels obsolete alarms.
List<PetNotification> buildNotificationPlan({
  required List<Reminder> reminders,
  required List<HealthAppointment> appointments,
  required tz.TZDateTime now,
}) {
  final plan = <PetNotification>[];
  for (final reminder in reminders.where((r) => r.isActive == 1)) {
    final time = reminder.reminderTime.split(':');
    final hour = int.tryParse(time.first) ?? -1;
    final minute = time.length == 2 ? int.tryParse(time.last) ?? -1 : -1;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) continue;
    var date = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!date.isAfter(now)) {
      date = tz.TZDateTime(
        now.location,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }
    plan.add(
      PetNotification(
        id: plan.length + 1,
        body: reminder.title,
        date: date,
        daily: true,
      ),
    );
  }
  final dated = <PetNotification>[];
  for (final appointment in appointments) {
    final record = appointment.record;
    if (!record.nextDueReminderEnabled || record.nextDueCompleted) continue;
    final time = record.nextDueReminderTime.split(':');
    final hour = int.tryParse(time.first) ?? -1;
    final minute = time.length == 2 ? int.tryParse(time.last) ?? -1 : -1;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) continue;
    final due = appointment.date;
    for (final daysBefore in [1, 0]) {
      final date = tz.TZDateTime(
        now.location,
        due.year,
        due.month,
        due.day - daysBefore,
        hour,
        minute,
      );
      if (!date.isAfter(now)) continue;
      dated.add(
        PetNotification(
          id: 0,
          body:
              '${appointment.pet.name}: ${record.title} ${daysBefore == 1 ? 'vào ngày mai' : 'đến hạn hôm nay'}.',
          date: date,
        ),
      );
    }
  }
  dated.sort((a, b) => a.date.compareTo(b.date));
  for (final notification in dated) {
    plan.add(
      PetNotification(
        id: plan.length + 1,
        body: notification.body,
        date: notification.date,
      ),
    );
  }
  return plan;
}
