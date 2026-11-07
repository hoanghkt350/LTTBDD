import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawpals_app/services/firebase_service.dart';
import 'package:pawpals_app/providers/pet_provider.dart';
import 'package:pawpals_app/models/pet_model.dart';
import 'package:pawpals_app/models/health_record_model.dart';
import 'package:pawpals_app/models/reminder_model.dart';
import 'package:pawpals_app/main.dart';

import 'helpers/auth_emulator.dart';

import 'package:pawpals_app/services/admin_service.dart';
import 'package:pawpals_app/services/order_workflow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    if (FirebaseService.isFirebaseInitialized) {
      await FirebaseService.instance.auth.signOut();
    }
  });
  tearDown(() async {
    if (FirebaseService.isFirebaseInitialized) {
      await FirebaseService.instance.auth.signOut();
    }
  });
  testWidgets(
    'Android Firebase Auth, offline SQLite, sync, checkout and cancellation',
    (tester) async {
      await tester.runAsync(() async {
        const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
        expect(
          host,
          isNotEmpty,
          reason: 'This test must only run against Firebase Emulator.',
        );
        await FirebaseService.initialize();
        expect(
          FirebaseService.isFirebaseInitialized,
          isTrue,
          reason: FirebaseService.initializationError,
        );
        final service = FirebaseService.instance;
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final email = 'android-$stamp@example.com';
        final user = await service.register(
          'Android Test',
          email,
          'TestPass123!',
        );
        expect(user.email, email);
        expect(service.auth.currentUser!.emailVerified, isFalse);
        expect(() => service.uid, throwsStateError);
        await verifyEmulatorEmail();
        await service.saveProfile(
          user.copyWith(phoneNumber: '0901234567', address: '123 Test Street'),
        );
        await service.auth.signOut();
        await expectLater(
          service.signInWithEmail(email, 'incorrect-password'),
          throwsA(isA<FirebaseAuthException>()),
        );
        expect(service.auth.currentUser, isNull);
        final signed = await service.signInWithEmail(email, 'TestPass123!');
        expect(signed.phoneNumber, '0901234567');

        final pets = PetProvider(signed.uid);
        addTearDown(pets.dispose);
        await pets.loadInitialData();
        for (var i = 0; pets.isSyncing && i < 300; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(pets.isSyncing, isFalse);
        expect(pets.syncError, isNull);
        await pets.addPet(
          Pet(
            name: 'Milo',
            species: 'Chó',
            breed: 'Golden',
            gender: 'Đực',
            birthDate: '2023-01-01',
            weight: 20,
          ),
        );
        final petId = pets.pets.single.id!;
        await pets.addHealthRecord(
          HealthRecord(
            petId: petId,
            recordType: 'CHECKUP',
            title: 'Health test',
            administeredDate: '2026-11-06',
          ),
        );
        // The host runner grants notification permission on the test emulator.
        await pets.addReminder(
          Reminder(
            petId: petId,
            title: 'Food',
            reminderTime: '23:59',
            notificationId: 0,
          ),
        );
        expect(pets.notificationError, isNull);
        expect(
          await FlutterLocalNotificationsPlugin().pendingNotificationRequests(),
          hasLength(1),
        );
        expect(await pets.syncDataToCloud(), isTrue, reason: pets.syncError);
        final cloud = await service
            .userCollection('pets')
            .get(const GetOptions(source: Source.server));
        expect(cloud.docs.single.data()['name'], 'Milo');
        expect(pets.pendingCount, 0);

        // Simulate an empty local cache on a second installation, then restore cloud data.
        await pets.store.replaceFromCloud({
          'pets': [],
          'health_records': [],
          'reminders': [],
        });
        expect(await pets.syncDataToCloud(), isTrue, reason: pets.syncError);
        expect(pets.pets.single.id, petId);
        expect(pets.getRecordsForPet(petId), hasLength(1));
        expect(pets.reminders, hasLength(1));

        final products = await service.getProducts();
        expect(products, isNotEmpty);
        final product = products.first;
        final id = 'android-$stamp';
        final data = <String, dynamic>{
          'quantities': {product.id: 1},
          'prices': {product.id: product.price},
          'voucher': 'PAWPALS10',
          'recipient': {
            'name': 'Android Test',
            'phone': '0901234567',
            'address': '123 Test Street',
          },
        };
        expect(await service.createOrder(data, orderId: id), id);
        expect(
          await service.createOrder(data, orderId: id),
          id,
        ); // Idempotent retry.
        final reserved = await service.firestore
            .collection('products')
            .doc(product.id)
            .get();
        expect(reserved.data()!['stock'], product.stock - 1);
        expect((await service.getOrders()).single['orderId'], id);
        await service.cancelOrder(id);
        final returned = await service.firestore
            .collection('products')
            .doc(product.id)
            .get();
        expect(returned.data()!['stock'], product.stock);
        await pets.deletePet(petId);
        expect(await pets.syncDataToCloud(), isTrue, reason: pets.syncError);
        expect(pets.pets, isEmpty);
        expect(pets.reminders, isEmpty);
        expect(
          await FlutterLocalNotificationsPlugin().pendingNotificationRequests(),
          isEmpty,
        );
        expect(
          (await service.userCollection('pets').doc('$petId').get())
              .data()!['deleted'],
          isTrue,
        );

        await service.auth.signOut();
        final other = await service.register(
          'Other',
          'other-$stamp@example.com',
          'TestPass123!',
        );
        await verifyEmulatorEmail();
        final otherPets = PetProvider(other.uid);
        addTearDown(otherPets.dispose);
        await otherPets.loadInitialData();
        for (var i = 0; otherPets.isSyncing && i < 300; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(otherPets.pets, isEmpty);
        expect(await service.getOrders(), isEmpty);
        await service.auth.signOut();
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
  testWidgets('Android UI registers and saves a pet through the real app', (
    tester,
  ) async {
    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 400 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(finder, findsWidgets);
    }

    await tester.pumpWidget(const PawPalsApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    final email = 'ui-${DateTime.now().millisecondsSinceEpoch}@example.com';
    await tester.enterText(find.byType(TextFormField).at(0), 'UI Test');
    await tester.enterText(find.byType(TextFormField).at(1), email);
    await tester.enterText(find.byType(TextFormField).at(2), 'TestPass123!');
    await tester.enterText(find.byType(TextFormField).at(3), 'TestPass123!');
    await tester.ensureVisible(find.text('TẠO TÀI KHOẢN'));
    await tester.tap(find.text('TẠO TÀI KHOẢN'));
    await waitFor(find.text('Xác nhận email của bạn'));
    expect(find.byType(NavigationBar), findsNothing);
    await tester.runAsync(verifyEmulatorEmail);
    await waitFor(find.byType(NavigationBar));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thêm thú cưng').first);
    await tester.tap(find.text('Thêm thú cưng').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Mimi UI');
    await tester.enterText(find.byType(TextFormField).at(1), 'Poodle');
    await tester.enterText(find.byType(TextFormField).at(2), '4.5');
    await tester.ensureVisible(find.text('LƯU HỒ SƠ'));
    await tester.tap(find.text('LƯU HỒ SƠ'));
    await waitFor(find.byType(NavigationBar));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Thú cưng'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mimi UI'), findsOneWidget);
    await tester.tap(find.text('Mimi UI'));
    await tester.pumpAndSettle();
    expect(find.text('Sổ sức khỏe'), findsOneWidget);
    expect(find.textContaining('4.5 kg'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => FirebaseService.instance.auth.signOut());
  }, timeout: const Timeout(Duration(minutes: 3)));
  testWidgets(
    'administrator claims, management writes, stock concurrency and revocation work through native SDK',
    (tester) async {
      await tester.runAsync(() async {
        final service = FirebaseService.instance;
        final admin = AdminService();
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final email = 'manager-$stamp@example.com';
        await service.register('Manager', email, 'TestPass123!');
        await verifyEmulatorEmail();
        await expectLater(admin.watch('products').first, throwsStateError);
        await setEmulatorAdmin(true);
        final data = <String, dynamic>{
          'name': 'Admin test $stamp',
          'category': 'FOOD',
          'petTarget': 'ALL',
          'price': 100000,
          'originalPrice': 100000,
          'stock': 10,
          'imageUrl': '',
          'description': 'Test product',
          'isFeatured': false,
          'isActive': true,
          'rating': 0,
          'reviewCount': 0,
        };
        await admin.save('products', null, data);
        final original = (await admin.watch('products').first).singleWhere(
          (p) => p['name'] == data['name'],
        );
        final id = original['_id'] as String;
        await service.auth.signOut();
        await service.register(
          'Customer',
          'buyer-$stamp@example.com',
          'TestPass123!',
        );
        await verifyEmulatorEmail();
        await service.createOrder({
          'quantities': {id: 1},
          'prices': {id: 100000.0},
          'voucher': '',
          'recipient': {
            'name': 'Buyer',
            'phone': '0901234567',
            'address': '123 Test Street',
          },
        }, orderId: 'admin-$stamp');
        await service.auth.signOut();
        await service.signInWithEmail(email, 'TestPass123!');
        await admin.save('products', id, {
          ...data,
          'name': 'Renamed $stamp',
        }, original: original);
        expect(
          (await service.firestore.collection('products').doc(id).get())
              .data()!['stock'],
          9,
        );
        await expectLater(
          admin.save('products', id, {
            ...data,
            'stock': 20,
          }, original: original),
          throwsStateError,
        );
        await admin.setProductActive(id, false);
        await admin.updateOrderStatus('admin-$stamp', OrderWorkflow.cancelled);
        expect(
          (await service.firestore.collection('products').doc(id).get())
              .data()!['stock'],
          10,
        );
        expect(
          (await admin.watch('orders').first).any(
            (o) => o['_id'] == 'admin-$stamp',
          ),
          isTrue,
        );
        await setEmulatorAdmin(false);
        await expectLater(admin.setProductActive(id, true), throwsStateError);
        await service.auth.signOut();
      });
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
