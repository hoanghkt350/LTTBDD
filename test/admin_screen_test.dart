import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pawpals_app/models/user_model.dart';
import 'package:pawpals_app/providers/auth_provider.dart';
import 'package:pawpals_app/services/admin_service.dart';
import 'package:pawpals_app/services/order_workflow.dart';
import 'package:pawpals_app/theme/app_theme.dart';
import 'package:pawpals_app/views/admin/admin_screen.dart';

class _Auth extends AuthProvider {
  bool admin = true;
  @override
  bool get isAdmin => admin;
  @override
  AppUser get user =>
      AppUser(uid: 'admin', email: 'admin@gmail.com', displayName: 'Admin');
  void revoke() {
    admin = false;
    notifyListeners();
  }
}

class _Service extends AdminService {
  int reads = 0, saves = 0;
  String? status;
  @override
  Stream<List<Map<String, dynamic>>> watch(
    String collection, {
    int limit = 100,
  }) {
    reads++;
    return Stream.value(switch (collection) {
      'products' => [
        {
          '_id': 'p1',
          'name': 'PawPals food',
          'price': 100000,
          'originalPrice': 100000,
          'stock': 10,
          'category': 'FOOD',
          'petTarget': 'ALL',
          'imageUrl': '',
          'description': 'Food',
          'weight': '1kg',
          'isFeatured': false,
          'isActive': true,
        },
      ],
      'orders' => [
        {
          '_id': 'o1',
          'status': OrderWorkflow.pending,
          'totalAmount': 125000,
          'recipient': {
            'name': 'Buyer',
            'phone': '0901234567',
            'address': '123 Test Street',
          },
          'items': {
            'p1': {'name': 'Food', 'price': 100000, 'quantity': 1},
          },
        },
      ],
      _ => [],
    });
  }

  @override
  Future<void> save(
    String collection,
    String? id,
    Map<String, dynamic> data, {
    Map<String, dynamic>? original,
  }) async {
    saves++;
  }

  @override
  Future<void> updateOrderStatus(String id, String value) async {
    status = value;
  }
}

Future<void> _mount(WidgetTester tester, _Auth auth, _Service service) =>
    tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: AdminScreen(service: service),
        ),
      ),
    );

void main() {
  testWidgets(
    'non-admin direct navigation is denied before any data subscription',
    (tester) async {
      final auth = _Auth()..admin = false;
      final service = _Service();
      await _mount(tester, auth, service);
      expect(find.text('Bạn không có quyền quản trị.'), findsOneWidget);
      expect(service.reads, 0);
      expect(find.text('Thêm mới'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
  for (final width in [320.0, 800.0]) {
    testWidgets(
      'admin catalog and product editor validate every field at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = _Auth(), service = _Service();
        await _mount(tester, auth, service);
        await tester.pumpAndSettle();
        expect(find.text('PawPals food'), findsOneWidget);
        await tester.tap(find.text('Thêm mới'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Lưu thay đổi'));
        await tester.tap(find.text('Lưu thay đổi'));
        await tester.pumpAndSettle();
        expect(service.saves, 0);
        expect(find.text('Vui lòng nhập Tên sản phẩm'), findsOneWidget);
        expect(find.text('Vui lòng nhập Giá bán (đ)'), findsOneWidget);
        expect(tester.takeException(), isNull);
        auth.revoke();
        await tester.pumpAndSettle();
        expect(find.text('Bạn không có quyền quản trị.'), findsOneWidget);
        expect(find.text('Lưu thay đổi'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        auth.dispose();
      },
    );
  }
  testWidgets('order actions require confirmation before dispatch', (
    tester,
  ) async {
    final auth = _Auth(), service = _Service();
    await _mount(tester, auth, service);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đơn hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Buyer'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Xác nhận giao hàng'));
    await tester.tap(find.text('Xác nhận giao hàng'));
    await tester.pumpAndSettle();
    expect(service.status, isNull);
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(service.status, OrderWorkflow.shipping);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });
}
