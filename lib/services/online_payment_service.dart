import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_service.dart';

class PaymentSession {
  const PaymentSession({
    required this.orderId,
    required this.paymentStatus,
    required this.mode,
    this.paymentUrl,
  });

  final String orderId;
  final String paymentStatus;
  final String mode;
  final String? paymentUrl;

  factory PaymentSession.fromMap(Map<String, dynamic> data) => PaymentSession(
    orderId: data['orderId'] as String,
    paymentStatus: data['paymentStatus'] as String,
    mode: data['mode'] as String,
    paymentUrl: data['paymentUrl'] as String?,
  );
}

class OnlinePaymentService {
  FirebaseService get _firebase => FirebaseService.instance;

  Future<PaymentSession> create(
    String orderId, {
    Map<String, dynamic>? checkout,
  }) => _call('createMomoPayment', {'orderId': orderId, 'checkout': checkout});

  Future<PaymentSession> check(String orderId) =>
      _call('checkMomoPayment', {'orderId': orderId});

  Future<PaymentSession> _call(String name, Map<String, dynamic> data) async {
    try {
      final response = await _firebase.functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 100),
            ),
          )
          .call<Map<String, dynamic>>(data);
      return PaymentSession.fromMap(response.data);
    } on FirebaseFunctionsException catch (error) {
      throw StateError(switch (error.code) {
        'not-found' || 'unimplemented' => 'Thanh toán MoMo chưa được kích hoạt. Bạn có thể chọn thanh toán khi nhận hàng.',
        'deadline-exceeded' => 'Chưa nhận được kết quả MoMo. Hãy kiểm tra lịch sử đơn hàng trước khi đặt lại.',
        _ => error.message ?? 'Chưa kết nối được MoMo. Hãy kiểm tra lịch sử đơn hàng trước khi thử lại.',
      });
    }
  }

  Stream<Map<String, dynamic>?> watchOrder(String orderId) => _firebase
      .firestore
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((snapshot) => snapshot.data());

  static bool isAllowedPaymentUrl(String value, String mode) {
    final uri = Uri.tryParse(value);
    return ['sandbox', 'production'].contains(mode) &&
        uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        (!uri.hasPort || uri.port == 443) &&
        uri.host ==
            (mode == 'production' ? 'payment.momo.vn' : 'test-payment.momo.vn');
  }

  Future<void> open(PaymentSession session) async {
    final url = session.paymentUrl;
    if (url == null || !isAllowedPaymentUrl(url, session.mode)) {
      throw StateError(
        'Chưa có đường dẫn MoMo hợp lệ. Hãy kiểm tra lại đơn hàng.',
      );
    }
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      throw StateError(
        'Không mở được MoMo. Bạn có thể thử lại từ đơn hàng này.',
      );
    }
  }
}
