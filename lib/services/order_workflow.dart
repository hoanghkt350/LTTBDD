class OrderWorkflow {
  static const pending = 'Chờ xác nhận';
  static const shipping = 'Đang giao';
  static const completed = 'Hoàn thành';
  static const cancelled = 'Đã hủy';

  static List<String> nextStatuses(String status) => switch (status) {
    pending => const [shipping, cancelled],
    shipping => const [completed],
    _ => const [],
  };
}
