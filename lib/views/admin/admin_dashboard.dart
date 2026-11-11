import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/admin_dashboard_model.dart';
import '../../services/admin_service.dart';
import '../../services/app_error.dart';
import '../../theme/app_theme.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
    required this.service,
    required this.onOrders,
    required this.onProducts,
  });
  final AdminService service;
  final VoidCallback onOrders, onProducts;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<AdminDashboardData> _data;
  final _money = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _data = widget.service.loadDashboard();
  }

  Future<void> _refresh() async {
    final future = widget.service.loadDashboard();
    setState(() {
      _data = future;
    });
    // FutureBuilder renders the error; the pull-to-refresh action also ends.
    try {
      await future;
    } catch (_) {}
  }

  Widget _metric(
    String label,
    String value,
    IconData icon, {
    String? detail,
    VoidCallback? onTap,
  }) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.secondary),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (detail != null)
              Text(
                detail,
                style: const TextStyle(color: AppTheme.textLight, fontSize: 12),
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminDashboardData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Chưa thể tải thống kê.'),
                const SizedBox(height: 8),
                Text(
                  errorMessage(snapshot.error!),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        );
      }
      final data = snapshot.data!;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            const Text(
              'Tổng quan hoạt động',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Cập nhật ${DateFormat('dd/MM/yyyy HH:mm').format(data.updatedAt)} • Kéo xuống để làm mới',
              style: const TextStyle(color: AppTheme.textLight, fontSize: 12),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth < 500
                    ? 1
                    : box.maxWidth < 900
                    ? 2
                    : 3;
                final metrics = [
                  _metric(
                    'Đơn chờ xác nhận',
                    '${data.pendingOrders}',
                    Icons.pending_actions,
                    onTap: widget.onOrders,
                  ),
                  _metric(
                    'Đơn đang giao',
                    '${data.shippingOrders}',
                    Icons.local_shipping_outlined,
                    onTap: widget.onOrders,
                  ),
                  _metric(
                    'Đơn mới hôm nay',
                    '${data.newOrdersToday}',
                    Icons.receipt_long_outlined,
                    onTap: widget.onOrders,
                  ),
                  _metric(
                    'Doanh thu hôm nay',
                    _money.format(data.revenueToday),
                    Icons.payments_outlined,
                    detail: '${data.completedToday} đơn hoàn thành',
                  ),
                  _metric(
                    'Doanh thu tháng ${data.updatedAt.month}',
                    _money.format(data.revenueMonth),
                    Icons.bar_chart,
                    detail: '${data.completedMonth} đơn hoàn thành',
                  ),
                  _metric(
                    'Sản phẩm sắp hết',
                    '${data.lowStock.length}',
                    Icons.inventory_2_outlined,
                    detail: 'Đang bán, tồn kho từ 0 đến 5',
                    onTap: widget.onProducts,
                  ),
                ];
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final metric in metrics)
                      SizedBox(
                        width: (box.maxWidth - (columns - 1) * 8) / columns,
                        child: metric,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Doanh thu COD là tổng tiền các đơn đã hoàn thành, gồm phí vận chuyển, tính theo thời điểm hoàn thành và giờ trên thiết bị. Đơn cũ chưa có thời điểm hoàn thành chưa được tính.',
              style: TextStyle(fontSize: 12, color: AppTheme.textLight),
            ),
            const SizedBox(height: 24),
            const Text(
              'Cần bổ sung tồn kho',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (data.lowStock.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Không có sản phẩm đang bán nào có tồn kho dưới 6.',
                ),
              ),
            for (final product in data.lowStock.take(20))
              Card(
                child: ListTile(
                  leading: Icon(
                    product.stock == 0
                        ? Icons.error_outline
                        : Icons.inventory_outlined,
                    color: product.stock == 0
                        ? Colors.red
                        : Colors.orange.shade800,
                  ),
                  title: Text(product.name),
                  subtitle: Text('Mã: ${product.id}'),
                  trailing: Text(
                    product.stock == 0 ? 'Hết hàng' : 'Còn ${product.stock}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: widget.onProducts,
                ),
              ),
            if (data.lowStock.length > 20)
              Text(
                'Hiển thị 20/${data.lowStock.length} sản phẩm. Xem thêm ở mục Sản phẩm.',
              ),
          ],
        ),
      );
    },
  );
}
