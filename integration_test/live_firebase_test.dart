import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawpals_app/main.dart';
import 'package:pawpals_app/services/firebase_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android connects to the real Firebase project and displays its catalog',
    (tester) async {
      const project = String.fromEnvironment('LIVE_FIREBASE_PROJECT');
      expect(
        project,
        isNotEmpty,
        reason: 'Explicitly specify the real project for this smoke check.',
      );
      expect(const String.fromEnvironment('FIREBASE_EMULATOR_HOST'), isEmpty);
      User? temporaryUser;
      String? firstProductName;
      try {
        await tester.runAsync(() async {
          await FirebaseService.initialize();
          expect(
            FirebaseService.isFirebaseInitialized,
            isTrue,
            reason: FirebaseService.initializationError,
          );
          final service = FirebaseService.instance;
          expect(service.firestore.app.options.projectId, project);
          // Do not disturb an existing user's signed-in session on the test device.
          expect(service.auth.currentUser, isNull);
          final random = Random.secure();
          final password =
              'PawPals!Aa1${base64UrlEncode(List.generate(24, (_) => random.nextInt(256)))}';
          final email =
              'pawpals-native-${DateTime.now().microsecondsSinceEpoch}@example.invalid';
          temporaryUser = (await service.auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          )).user;
          final products = await service.getProducts();
          expect(products, isNotEmpty);
          firstProductName = products.first.name;
        });

        await tester.pumpWidget(const PawPalsApp());
        for (
          var i = 0;
          i < 300 && find.byType(BottomNavigationBar).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        expect(find.byType(BottomNavigationBar), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text('Cửa hàng'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(firstProductName!), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          if (temporaryUser != null) await temporaryUser!.delete();
        });
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
