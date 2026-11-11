import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:pawpals_app/models/health_record_model.dart';
import 'package:pawpals_app/models/pet_model.dart';
import 'package:pawpals_app/models/reminder_model.dart';
import 'package:pawpals_app/providers/pet_provider.dart';
import 'package:pawpals_app/services/admin_service.dart';
import 'package:pawpals_app/services/firebase_service.dart';
import 'package:pawpals_app/services/notification_service.dart';
import 'package:pawpals_app/services/order_workflow.dart';

import 'helpers/auth_emulator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android schedules and cancels dated appointments, syncs completion and aggregates the admin dashboard',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.runAsync(() async {
        const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
        const port = int.fromEnvironment(
          'FIRESTORE_EMULATOR_PORT',
          defaultValue: 8180,
        );
        expect(
          host,
          isNotEmpty,
          reason: 'This test only runs against local Firebase emulators.',
        );
        await FirebaseService.initialize();
        final service = FirebaseService.instance;
        expect(service.firestore.app.options.projectId, 'demo-pawpals');
        await service.auth.signOut();
        final stamp = DateTime.now().microsecondsSinceEpoch;
        final user = await service.register(
          'Feature Test',
          'features-$stamp@example.com',
          'FeatureTest123!',
        );
        await verifyEmulatorEmail();
        await setEmulatorAdmin(true);
        final admin = AdminService();
        final now = DateTime(2031, 6, 15, 12);
        final baseline = await admin.loadDashboard(now: now);
        final paths = <String>[];
        PetProvider? pets;
        final base =
            'http://$host:$port/v1/projects/demo-pawpals/databases/(default)/documents';
        const headers = {
          'Authorization': 'Bearer owner',
          'Content-Type': 'application/json',
        };
        try {
          for (final active in [true, false]) {
            final id = 'features-${active ? 'low' : 'inactive'}-$stamp';
            paths.add('products/$id');
            await admin.save('products', id, {
              'name': 'Feature stock test',
              'category': 'FOOD',
              'petTarget': 'ALL',
              'price': 100000,
              'originalPrice': 100000,
              'stock': active ? 0 : 1,
              'imageUrl': '',
              'description': '',
              'isFeatured': false,
              'isActive': active,
            });
          }
          final created = Timestamp.fromDate(DateTime(2031, 6, 15, 9));
          for (final status in [
            OrderWorkflow.pending,
            OrderWorkflow.completed,
            OrderWorkflow.cancelled,
          ]) {
            final id = 'features-order-${paths.length}-$stamp';
            paths.add('orders/$id');
            final response = await http.patch(
              Uri.parse('$base/orders/$id'),
              headers: headers,
              body: jsonEncode({
                'fields': {
                  'orderId': {'stringValue': id},
                  'userId': {'stringValue': user.uid},
                  'status': {'stringValue': status},
                  'totalAmount': {'integerValue': '125000'},
                  'createdAt': {
                    'timestampValue': created
                        .toDate()
                        .toUtc()
                        .toIso8601String(),
                  },
                  'statusUpdatedAt': {
                    'timestampValue': created
                        .toDate()
                        .toUtc()
                        .toIso8601String(),
                  },
                },
              }),
            );
            expect(response.statusCode, 200);
          }
          final dashboard = await admin.loadDashboard(now: now);
          expect(dashboard.pendingOrders, baseline.pendingOrders + 1);
          expect(dashboard.newOrdersToday, baseline.newOrdersToday + 3);
          expect(dashboard.completedToday, baseline.completedToday + 1);
          expect(dashboard.completedMonth, baseline.completedMonth + 1);
          expect(dashboard.revenueToday, baseline.revenueToday + 125000);
          expect(dashboard.revenueMonth, baseline.revenueMonth + 125000);
          expect(
            dashboard.lowStock.map((p) => p.id),
            contains('features-low-$stamp'),
          );
          expect(
            dashboard.lowStock.map((p) => p.id),
            isNot(contains('features-inactive-$stamp')),
          );
          debugPrint('Native dashboard aggregates verified.');

          pets = PetProvider(user.uid);
          await pets.loadInitialData();
          for (var attempt = 0; pets.isSyncing && attempt < 300; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          expect(pets.isSyncing, isFalse);
          await pets.addPet(
            Pet(
              id: 101,
              name: 'Milo',
              species: 'Dog',
              breed: 'Corgi',
              gender: 'Đực',
              birthDate: '2025-01-01',
              weight: 8,
            ),
          );
          paths.add('users/${user.uid}/pets/101');
          final today = DateTime.now();
          final due = DateFormat('yyyy-MM-dd')
              .format(DateTime(today.year, today.month, today.day + 2));
          final record = HealthRecord(
            id: 102,
            petId: 101,
            recordType: 'VACCINE',
            title: 'Feature appointment',
            administeredDate: DateFormat('yyyy-MM-dd').format(today),
            nextDueDate: due,
            nextDueReminderTime: '09:30',
          );
          await pets.addHealthRecord(record);
          debugPrint('Native dated appointment saved.');
          paths.add('users/${user.uid}/health_records/102');
          expect(pets.notificationError, isNull);
          final plugin = FlutterLocalNotificationsPlugin();
          expect(await plugin.pendingNotificationRequests(), hasLength(2));
          await pets.addReminder(
            Reminder(
              id: 103,
              petId: 101,
              title: 'Daily food',
              reminderTime: '23:59',
              notificationId: 0,
            ),
          );
          paths.add('users/${user.uid}/reminders/103');
          final combined = await plugin.pendingNotificationRequests();
          expect(combined, hasLength(3));
          expect(combined.map((n) => n.id).toSet(), hasLength(3));
          await pets.completeAppointment(102, true);
          expect(await plugin.pendingNotificationRequests(), hasLength(1));
          expect(await pets.syncDataToCloud(), isTrue, reason: pets.syncError);
          final saved = await service
              .userCollection('health_records')
              .doc('102')
              .get(const GetOptions(source: Source.server));
          expect(saved.data()?['next_due_completed'], isTrue);
          expect(saved.data()?['next_due_reminder_time'], '09:30');
          debugPrint('Native appointment completion synchronized.');
          await pets.completeAppointment(102, false);
          expect(await plugin.pendingNotificationRequests(), hasLength(3));
          await pets.addHealthRecord(
            HealthRecord.fromMap({
              ...record.toMap(),
              'next_due_date': '2020-01-01',
            }),
          );
          expect(await plugin.pendingNotificationRequests(), hasLength(1));
          await pets.addHealthRecord(record);
          expect(await plugin.pendingNotificationRequests(), hasLength(3));
          await pets.deleteHealthRecord(102);
          expect(await plugin.pendingNotificationRequests(), hasLength(1));
          await NotificationService.instance.clear();
          expect(await plugin.pendingNotificationRequests(), isEmpty);
          await setEmulatorAdmin(false);
          await expectLater(admin.loadDashboard(now: now), throwsStateError);
          debugPrint(
            'Native notification lifecycle and role revocation verified.',
          );
        } finally {
          pets?.dispose();
          await NotificationService.instance.clear();
          for (final path in [...paths, 'users/${user.uid}']) {
            final response = await http.delete(
              Uri.parse('$base/$path'),
              headers: headers,
            );
            expect(response.statusCode, anyOf(200, 404));
          }
          await service.auth.currentUser?.delete();
        }
      });
    },
  );
}
