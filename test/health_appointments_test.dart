import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:pawpals_app/models/health_record_model.dart';
import 'package:pawpals_app/models/pet_model.dart';
import 'package:pawpals_app/models/reminder_model.dart';
import 'package:pawpals_app/providers/pet_provider.dart';
import 'package:pawpals_app/services/database_helper.dart';
import 'package:pawpals_app/services/health_appointments.dart';
import 'package:pawpals_app/services/notification_plan.dart';

final _pet = Pet(
  id: 1,
  name: 'Milo',
  species: 'Dog',
  breed: 'Corgi',
  gender: 'Đực',
  birthDate: '2025-01-01',
  weight: 8,
);
HealthRecord _record({
  String due = '2026-11-10',
  bool completed = false,
  bool enabled = true,
  String time = '08:00',
}) => HealthRecord(
  id: 2,
  petId: 1,
  recordType: 'VACCINE',
  title: 'Tiêm nhắc lại',
  administeredDate: '2026-10-01',
  nextDueDate: due,
  nextDueCompleted: completed,
  nextDueReminderEnabled: enabled,
  nextDueReminderTime: time,
);
HealthAppointment _appointment(HealthRecord record) =>
    HealthAppointment(record: record, pet: _pet);

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    sqfliteFfiInit();
  });

  test('old health records retain their date and gain compatible reminder defaults', () {
    final data = _record().toMap()
      ..remove('next_due_completed')
      ..remove('next_due_reminder_enabled')
      ..remove('next_due_reminder_time');
    final record = HealthRecord.fromMap(data);
    expect(record.nextDueDate, '2026-11-10');
    expect(record.nextDueReminderEnabled, isTrue);
    expect(record.nextDueCompleted, isFalse);
    expect(record.nextDueReminderTime, '08:00');
    expect(
      HealthRecord.fromMap(
        _record(completed: true, enabled: false, time: '15:30').toMap(),
      ).nextDueReminderTime,
      '15:30',
    );
  });

  test(
    'appointment statuses use calendar days, including overdue and completion',
    () {
      final now = DateTime(2026, 11, 8, 23, 59);
      for (final entry in {
        '2026-11-07': AppointmentStatus.overdue,
        '2026-11-08': AppointmentStatus.today,
        '2026-11-15': AppointmentStatus.upcoming,
        '2026-11-16': AppointmentStatus.scheduled,
      }.entries) {
        expect(_appointment(_record(due: entry.key)).status(now), entry.value);
      }
      expect(
        _appointment(_record(due: '2026-01-01', completed: true)).status(now),
        AppointmentStatus.completed,
      );
    },
  );

  test('appointment notifications occur once before and on the date at the chosen local time', () {
    final zone = tz.getLocation('Asia/Ho_Chi_Minh');
    final plan = buildNotificationPlan(
      reminders: [],
      appointments: [_appointment(_record(time: '09:30'))],
      now: tz.TZDateTime(zone, 2026, 11, 8),
    );
    expect(plan.map((n) => n.date), [
      tz.TZDateTime(zone, 2026, 11, 9, 9, 30),
      tz.TZDateTime(zone, 2026, 11, 10, 9, 30),
    ]);
    expect(plan.every((n) => !n.daily), isTrue);
    expect(plan.first.body, contains('Milo'));
    expect(plan.first.body, contains('ngày mai'));
  });

  test('past, completed and disabled appointments never schedule stale notifications', () {
    final zone = tz.getLocation('Asia/Ho_Chi_Minh');
    final plan = buildNotificationPlan(
      reminders: [],
      appointments: [
        _appointment(_record(due: '2026-11-07')),
        _appointment(_record(completed: true)),
        _appointment(_record(enabled: false)),
        _appointment(_record(due: '2026-11-08')),
      ],
      now: tz.TZDateTime(zone, 2026, 11, 8, 9),
    );
    expect(plan, isEmpty);
    final today = buildNotificationPlan(
      reminders: [],
      appointments: [_appointment(_record(due: '2026-11-08', time: '10:00'))],
      now: tz.TZDateTime(zone, 2026, 11, 8, 9),
    );
    expect(today, hasLength(1));
    expect(today.single.date.day, 8);
  });

  test(
    'daily and dated alarms have unique IDs even when stored IDs collide',
    () {
      final zone = tz.getLocation('Asia/Ho_Chi_Minh');
      final plan = buildNotificationPlan(
        reminders: [
          Reminder(
            id: 1,
            petId: 1,
            title: 'Ăn sáng',
            reminderTime: '08:00',
            notificationId: 2,
          ),
          Reminder(
            id: 2,
            petId: 1,
            title: 'Uống nước',
            reminderTime: '09:00',
            notificationId: 2,
          ),
        ],
        appointments: [_appointment(_record())],
        now: tz.TZDateTime(zone, 2026, 11, 8, 8),
      );
      expect(plan.map((n) => n.id).toSet(), hasLength(4));
      expect(plan.first.date, tz.TZDateTime(zone, 2026, 11, 9, 8));
      expect(plan.take(2).every((n) => n.daily), isTrue);
    },
  );

  test(
    'reminders preserve local wall-clock time across a daylight-saving change',
    () {
      final zone = tz.getLocation('Europe/Berlin');
      final plan = buildNotificationPlan(
        reminders: [
          Reminder(
            petId: 1,
            title: 'Ăn sáng',
            reminderTime: '08:00',
            notificationId: 1,
          ),
        ],
        appointments: [_appointment(_record(due: '2026-10-25'))],
        now: tz.TZDateTime(zone, 2026, 10, 24, 10),
      );
      expect(plan, hasLength(2));
      expect(plan.every((n) => n.date.hour == 8 && n.date.day == 25), isTrue);
    },
  );

  test(
    'completion and reopening persist in the offline outbox and survive reload',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
      );
      await DatabaseHelper.createSchema(database);
      final store = DatabaseHelper('alice', suppliedDatabase: database);
      final provider = PetProvider('alice', store: store);
      await provider.addPet(_pet);
      await provider.addHealthRecord(_record());
      expect(provider.appointments, hasLength(1));
      await provider.completeAppointment(2, true);
      expect(provider.appointments.single.record.nextDueCompleted, isTrue);
      expect(
        (await store.read('health_records')).single['next_due_completed'],
        isTrue,
      );
      expect(
        (await store.pending()).firstWhere(
          (e) => e['collection'] == 'health_records',
        )['payload'],
        contains('"next_due_completed":true'),
      );
      await provider.updatePet(_pet.copyWith(name: 'Milo mới'));
      expect(provider.appointments.single.record.nextDueCompleted, isTrue);
      expect(provider.appointments.single.pet.name, 'Milo mới');
      await provider.completeAppointment(2, false);
      expect(provider.appointments.single.record.nextDueCompleted, isFalse);
      await provider.deletePet(1);
      expect(provider.appointments, isEmpty);
      expect(
        (await store.pending()).firstWhere(
          (e) => e['collection'] == 'health_records',
        )['payload'],
        contains('"deleted":true'),
      );
      provider.dispose();
      await Future<void>.delayed(Duration.zero);
    },
  );
}
