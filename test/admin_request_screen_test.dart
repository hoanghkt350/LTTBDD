import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpals_app/models/admin_request_model.dart';
import 'package:pawpals_app/services/admin_request_service.dart';
import 'package:pawpals_app/theme/app_theme.dart';
import 'package:pawpals_app/views/profile/admin_request_screen.dart';

class _Service extends AdminRequestService {
  final updates = StreamController<AdminRequest?>.broadcast();
  AdminRequest? request;
  int submissions = 0;
  bool fail = false;
  @override
  Stream<AdminRequest?> watchMine() async* {
    yield request;
    yield* updates.stream;
  }

  @override
  Future<void> submit(String reason) async {
    submissions++;
    if (fail) throw StateError('Không kết nối được Firebase.');
    request = AdminRequest(
      uid: 'alice',
      email: 'alice@example.com',
      displayName: 'Alice',
      reason: reason,
      status: AdminRequest.pending,
    );
    updates.add(request);
  }
}

Future<void> _mount(WidgetTester tester, _Service service) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.lightTheme,
    home: AdminRequestScreen(service: service),
  ),
);

void main() {
  for (final width in [320.0, 800.0]) {
    testWidgets(
      'applicant validates reason, submits once and sees pending status at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _Service();
        await _mount(tester, service);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Gửi yêu cầu'));
        await tester.tap(find.text('Gửi yêu cầu'));
        await tester.pumpAndSettle();
        expect(service.submissions, 0);
        expect(
          find.text('Vui lòng nhập lý do ít nhất 10 ký tự.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byType(TextFormField),
          'Tôi phụ trách cập nhật danh mục sản phẩm.',
        );
        await tester.ensureVisible(find.text('Gửi yêu cầu'));
        await tester.tap(find.text('Gửi yêu cầu'));
        await tester.pumpAndSettle();
        expect(service.submissions, 1);
        expect(find.text('Chờ duyệt'), findsOneWidget);
        expect(find.text('Gửi yêu cầu'), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await service.updates.close();
      },
    );
  }

  testWidgets('rejection shows feedback and permits a new request', (
    tester,
  ) async {
    final service = _Service()
      ..request = const AdminRequest(
        uid: 'alice',
        email: 'alice@example.com',
        displayName: 'Alice',
        reason: 'Tôi muốn quản lý sản phẩm.',
        status: AdminRequest.rejected,
        reviewNote: 'Cần mô tả rõ công việc.',
      );
    await _mount(tester, service);
    await tester.pumpAndSettle();
    expect(find.text('Đã từ chối'), findsOneWidget);
    expect(find.textContaining('Cần mô tả rõ công việc.'), findsOneWidget);
    expect(find.text('Gửi lại yêu cầu'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await service.updates.close();
  });

  testWidgets('failed submission keeps the draft and never reports success', (
    tester,
  ) async {
    final service = _Service()..fail = true;
    await _mount(tester, service);
    await tester.pumpAndSettle();
    const reason = 'Tôi cần cập nhật bài viết cho cửa hàng.';
    await tester.enterText(find.byType(TextFormField), reason);
    await tester.ensureVisible(find.text('Gửi yêu cầu'));
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    expect(find.text('Không kết nối được Firebase.'), findsOneWidget);
    expect(find.text(reason), findsOneWidget);
    expect(find.text('Chờ duyệt'), findsNothing);
    expect(find.textContaining('Đã gửi yêu cầu.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await service.updates.close();
  });

  testWidgets('approval replaces the form with entry to the admin workspace', (
    tester,
  ) async {
    final service = _Service();
    await _mount(tester, service);
    await tester.pumpAndSettle();
    service.updates.add(
      const AdminRequest(
        uid: 'alice',
        email: 'alice@example.com',
        displayName: 'Alice',
        reason: 'Tôi cần cập nhật cửa hàng.',
        status: AdminRequest.approved,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đã được cấp quyền'), findsOneWidget);
    expect(find.text('Mở Trung tâm quản trị'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await service.updates.close();
  });
}
