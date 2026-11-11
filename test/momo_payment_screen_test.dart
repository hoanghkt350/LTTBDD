import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpals_app/services/online_payment_service.dart';
import 'package:pawpals_app/services/order_payment.dart';
import 'package:pawpals_app/theme/app_theme.dart';
import 'package:pawpals_app/views/cart/momo_payment_screen.dart';

class _Payments extends OnlinePaymentService {
  final changes = StreamController<Map<String, dynamic>?>.broadcast();
  Map<String, dynamic> order = {
    'orderId': 'order-0001',
    'paymentMethod': 'MOMO',
    'paymentStatus': 'pending',
    'paymentEnvironment': 'production',
    'status': 'Chờ thanh toán',
    'totalAmount': 125000,
  };
  int opens = 0, checks = 0, creates = 0;
  bool failOpen = false;
  String checkStatus = 'pending';

  PaymentSession session(String status) => PaymentSession(
    orderId: 'order-0001',
    paymentStatus: status,
    mode: order['paymentEnvironment'] as String,
    paymentUrl: 'https://payment.momo.vn/v2/gateway/pay?t=fixture',
  );

  @override
  Stream<Map<String, dynamic>?> watchOrder(String orderId) async* {
    yield Map.of(order);
    yield* changes.stream;
  }

  @override
  Future<PaymentSession> create(
    String orderId, {
    Map<String, dynamic>? checkout,
  }) async {
    creates++;
    return session('pending');
  }

  @override
  Future<PaymentSession> check(String orderId) async {
    checks++;
    return session(checkStatus);
  }

  @override
  Future<void> open(PaymentSession session) async {
    opens++;
    if (failOpen) throw StateError('Không mở được MoMo. Hãy thử lại.');
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Payments payments, {
  PaymentSession? initial,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: MomoPaymentScreen(
        orderId: 'order-0001',
        service: payments,
        initialSession: initial,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 800.0]) {
    testWidgets(
      'payment stays pending until the order stream confirms success at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final payments = _Payments()..checkStatus = 'paid';
        addTearDown(payments.changes.close);
        await _mount(tester, payments);
        await tester.tap(find.text('Mở MoMo để thanh toán'));
        await tester.pumpAndSettle();
        expect(payments.opens, 1);
        expect(payments.creates, 1);
        await tester.tap(find.text('Kiểm tra thanh toán'));
        await tester.pumpAndSettle();
        expect(payments.checks, 1);
        // A callable return or browser result cannot make the UI claim success.
        expect(find.text('Đã thanh toán MoMo'), findsNothing);
        payments.changes.add({
          ...payments.order,
          'paymentStatus': 'paid',
          'status': 'Chờ xác nhận',
        });
        await tester.pumpAndSettle();
        expect(find.text('Đã thanh toán MoMo'), findsOneWidget);
        expect(find.text('Mở MoMo để thanh toán'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'browser launch failure preserves the pending order and retry action',
    (tester) async {
      final payments = _Payments()..failOpen = true;
      addTearDown(payments.changes.close);
      await _mount(tester, payments, initial: payments.session('pending'));
      expect(payments.opens, 1);
      expect(find.text('Không mở được MoMo. Hãy thử lại.'), findsOneWidget);
      expect(find.text('Chờ thanh toán MoMo'), findsOneWidget);
      expect(find.text('Đã thanh toán MoMo'), findsNothing);
    },
  );

  testWidgets('sandbox success explicitly says no real money or delivery', (
    tester,
  ) async {
    final payments = _Payments();
    payments.order.addAll({
      'paymentEnvironment': 'sandbox',
      'paymentStatus': 'paid',
      'status': 'Thử nghiệm thành công',
    });
    addTearDown(payments.changes.close);
    await _mount(tester, payments);
    expect(find.text('Thanh toán thử nghiệm thành công'), findsOneWidget);
    expect(find.textContaining('Không thu tiền thật'), findsOneWidget);
    expect(find.text('Mở MoMo để thanh toán'), findsNothing);
  });

  testWidgets(
    'late payment asks for reconciliation without offering to pay again',
    (tester) async {
      final payments = _Payments();
      payments.order.addAll({
        'paymentStatus': 'review_required',
        'status': 'Cần đối soát',
        'paymentTransactionId': '123456789',
      });
      addTearDown(payments.changes.close);
      await _mount(tester, payments);
      expect(find.text('Cần cửa hàng đối soát'), findsOneWidget);
      expect(
        find.textContaining('Mã giao dịch MoMo: 123456789'),
        findsOneWidget,
      );
      expect(find.text('Mở MoMo để thanh toán'), findsNothing);
    },
  );

  test(
    'payment links reject spoofed hosts, mixed environments and other schemes',
    () {
      expect(
        OnlinePaymentService.isAllowedPaymentUrl(
          'https://payment.momo.vn/pay',
          'production',
        ),
        isTrue,
      );
      expect(
        OnlinePaymentService.isAllowedPaymentUrl(
          'https://test-payment.momo.vn/pay',
          'sandbox',
        ),
        isTrue,
      );
      for (final url in [
        'https://payment.momo.vn.evil.example/pay',
        'http://payment.momo.vn/pay',
        'https://payment.momo.vn@evil.example/pay',
        'https://test-payment.momo.vn/pay',
        'javascript:alert(1)',
        'https://payment.momo.vn:8443/pay',
      ]) {
        expect(
          OnlinePaymentService.isAllowedPaymentUrl(url, 'production'),
          isFalse,
        );
      }
    },
  );

  test('only paid production MoMo orders can be fulfilled; COD cancellation stays available', () {
    final pending = {
      'paymentMethod': 'MOMO',
      'paymentStatus': 'pending',
      'status': 'Chờ thanh toán',
    };
    expect(OrderPayment.canFulfill(pending), isFalse);
    expect(OrderPayment.canCancel(pending), isFalse);
    expect(
      OrderPayment.canFulfill({
        ...pending,
        'paymentStatus': 'paid',
        'paymentEnvironment': 'sandbox',
      }),
      isFalse,
    );
    expect(
      OrderPayment.canFulfill({
        ...pending,
        'paymentStatus': 'paid',
        'paymentEnvironment': 'production',
      }),
      isTrue,
    );
    expect(
      OrderPayment.canCancel({
        'paymentMethod': 'COD',
        'status': 'Chờ xác nhận',
      }),
      isTrue,
    );
  });
}
