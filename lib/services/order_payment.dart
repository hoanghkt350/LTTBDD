class OrderPayment {
  static const cod = 'COD';
  static const momo = 'MOMO';

  static bool isOnline(Map<String, dynamic> order) =>
      order['paymentMethod'] == momo;

  static bool canCancel(Map<String, dynamic> order) =>
      !isOnline(order) && order['status'] == 'Chờ xác nhận';

  static bool canFulfill(Map<String, dynamic> order) =>
      !isOnline(order) ||
      (order['paymentStatus'] == 'paid' &&
          order['paymentEnvironment'] == 'production');

  static String description(Map<String, dynamic> order) {
    if (!isOnline(order)) return 'Thanh toán khi nhận hàng (COD)';
    final suffix = order['paymentEnvironment'] == 'sandbox'
        ? ' • Thử nghiệm'
        : '';
    final status = switch (order['paymentStatus']) {
      'paid' => 'Đã thanh toán',
      'failed' => 'Thanh toán không thành công',
      'review_required' => 'Cần cửa hàng đối soát',
      _ => 'Chờ thanh toán',
    };
    return 'MoMo • $status$suffix';
  }
}
