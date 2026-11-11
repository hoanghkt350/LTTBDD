class LowStockProduct {
  const LowStockProduct({
    required this.id,
    required this.name,
    required this.stock,
  });
  final String id, name;
  final int stock;
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.updatedAt,
    this.pendingOrders = 0,
    this.shippingOrders = 0,
    this.newOrdersToday = 0,
    this.completedToday = 0,
    this.completedMonth = 0,
    this.revenueToday = 0,
    this.revenueMonth = 0,
    this.lowStock = const [],
  });

  final DateTime updatedAt;
  final int pendingOrders, shippingOrders, newOrdersToday;
  final int completedToday, completedMonth;
  final double revenueToday, revenueMonth;
  final List<LowStockProduct> lowStock;
}
