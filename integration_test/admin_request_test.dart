import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase, FirebaseApp;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:pawpals_app/main.dart';
import 'package:pawpals_app/models/admin_request_model.dart';
import 'package:pawpals_app/services/admin_request_service.dart';
import 'package:pawpals_app/services/admin_service.dart';
import 'package:pawpals_app/services/firebase_service.dart';
import 'package:pawpals_app/views/admin/admin_screen.dart';

import 'helpers/auth_emulator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a member requests access, receives approval live and loses access on revocation',
    (tester) async {
      const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
      const authPort = int.fromEnvironment(
        'FIREBASE_AUTH_EMULATOR_PORT',
        defaultValue: 9099,
      );
      const storePort = int.fromEnvironment(
        'FIRESTORE_EMULATOR_PORT',
        defaultValue: 8080,
      );
      expect(host, isNotEmpty, reason: 'Run only with Firebase emulators.');
      final service = FirebaseService.instance;
      final requests = AdminRequestService();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final managerEmail = 'request-manager-$stamp@example.com';
      final memberEmail = 'request-member-$stamp@example.com';
      const password = 'PawPalsTest123!';
      late String memberUid, managerUid;
      late FirebaseApp reviewerApp;
      late FirebaseAuth reviewerAuth;
      late FirebaseFirestore reviewerStore;

      Future<void> waitFor(Finder finder) async {
        for (
          var attempt = 0;
          attempt < 300 && finder.evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(finder, findsWidgets);
      }

      await tester.runAsync(() async {
        await FirebaseService.initialize();
        expect(service.auth.app.options.projectId, 'demo-pawpals');
        await service.auth.signOut();
        final manager = await service.register(
          'Request Manager',
          managerEmail,
          password,
        );
        managerUid = manager.uid;
        await verifyEmulatorEmail();
        await setEmulatorAdmin(true);
        await service.auth.signOut();
        final member = await service.register(
          'Request Member',
          memberEmail,
          password,
        );
        memberUid = member.uid;
        await verifyEmulatorEmail();
        expect(await service.hasAdminAccess(), isFalse);
        await requests.submit('Tôi phụ trách cập nhật danh mục sản phẩm.');
        await expectLater(
          requests.submit('Yêu cầu gửi trùng không được chấp nhận.'),
          throwsStateError,
        );
        await expectLater(
          requests.review(memberUid, AdminRequest.approved),
          throwsStateError,
        );
        await service.auth.signOut();
        await service.signInWithEmail(managerEmail, password);
        await requests.review(
          memberUid,
          AdminRequest.rejected,
          note: 'Mô tả thêm công việc phụ trách.',
        );
        await service.auth.signOut();
        await service.signInWithEmail(memberEmail, password);
        final rejected = await requests.watchMine().first;
        expect(rejected!.status, AdminRequest.rejected);
        expect(rejected.reviewNote, 'Mô tả thêm công việc phụ trách.');
        await requests.submit(
          'Tôi cập nhật sản phẩm và xử lý đơn hàng cho cửa hàng.',
        );

        // A second real client acts as the reviewer while the member stays signed in.
        reviewerApp = await Firebase.initializeApp(
          name: 'request-reviewer-$stamp',
          options: service.auth.app.options,
        );
        reviewerAuth = FirebaseAuth.instanceFor(app: reviewerApp);
        await reviewerAuth.useAuthEmulator(host, authPort);
        reviewerStore = FirebaseFirestore.instanceFor(app: reviewerApp);
        reviewerStore.useFirestoreEmulator(host, storePort);
        await reviewerAuth.signInWithEmailAndPassword(
          email: managerEmail,
          password: password,
        );
      });

      await tester.pumpWidget(const PawPalsApp());
      await waitFor(find.byType(NavigationBar));
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Tài khoản'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Yêu cầu quyền quản trị'));
      await tester.tap(find.text('Yêu cầu quyền quản trị'));
      await waitFor(find.text('Chờ duyệt'));
      expect(find.text('Mở Trung tâm quản trị'), findsNothing);

      Future<void> decide(String status) => reviewerStore.runTransaction((
        tx,
      ) async {
        final ref = reviewerStore.collection('admin_requests').doc(memberUid);
        await tx.get(ref);
        tx.update(ref, {
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': managerUid,
          'reviewNote': 'Đã xem xét công việc.',
        });
      });

      await tester.runAsync(() => decide(AdminRequest.approved));
      await waitFor(find.text('Đã được cấp quyền'));
      await tester.runAsync(() async {
        expect(
          (await service.auth.currentUser!.getIdTokenResult()).claims?['admin'],
          isNot(true),
        );
        await service.requireAdmin();
      });
      await tester.ensureVisible(find.text('Mở Trung tâm quản trị'));
      await tester.tap(find.text('Mở Trung tâm quản trị'));
      await waitFor(find.byType(AdminScreen));
      await waitFor(find.text('Yêu cầu cấp quyền'));
      await tester.runAsync(() => decide(AdminRequest.revoked));
      await waitFor(find.text('Bạn không có quyền quản trị.'));
      await tester.runAsync(() async {
        await expectLater(service.requireAdmin(), throwsStateError);
        await expectLater(
          AdminService().watch('users').first,
          throwsStateError,
        );
      });

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        for (final document in [
          'admin_requests/$memberUid',
          'users/$memberUid',
          'users/$managerUid',
        ]) {
          final response = await http.delete(
            Uri.parse(
              'http://$host:$storePort/v1/projects/demo-pawpals/databases/(default)/documents/$document',
            ),
            headers: {'Authorization': 'Bearer owner'},
          );
          expect(response.statusCode, anyOf(200, 404));
        }
        await reviewerAuth.signOut();
        await reviewerStore.terminate();
        await reviewerApp.delete();
        await service.auth.currentUser!.delete();
        await service.signInWithEmail(managerEmail, password);
        await service.auth.currentUser!.delete();
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
