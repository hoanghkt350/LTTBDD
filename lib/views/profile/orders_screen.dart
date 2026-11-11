import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/firebase_service.dart';
import '../../services/app_error.dart';
import '../../services/order_payment.dart';
import '../cart/momo_payment_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final Stream<List<Map<String, dynamic>>> _orders;
  final _busy = <String>{};
  final _money = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );
  @override
  void initState() {
    super.initState();
    _orders = FirebaseService.instance.watchOrders();
  }

  Future<void> _cancel(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đơn hàng?'),
        content: const Text('Chỉ có thể hủy đơn đang chờ xác nhận.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy.add(id));
    try {
      await FirebaseService.instance.cancelOrder(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đơn hàng của tôi')),
    body: StreamBuilder<List<Map<String, dynamic>>>(
      stream: _orders,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(errorMessage(snapshot.error!)),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('Bạn chưa có đơn hàng.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.map((order) {
            final items = Map<String, dynamic>.from(order['items'] as Map);
            final recipient = Map<String, dynamic>.from(
              order['recipient'] as Map,
            );
            final date = (order['createdAt'] as Timestamp?)?.toDate();
            final id = order['orderId'] as String;
            return Card(
              child: ExpansionTile(
                title: Text(
                  'Đơn $id',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${order['status']} • ${_money.format(order['totalAmount'])}\n${date == null ? 'Đang cập nhật' : DateFormat('dd/MM/yyyy HH:mm').format(date)}',
                ),
                childrenPadding: const EdgeInsets.all(16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...items.values.map(
                    (item) => Text(
                      '${item['quantity']} × ${item['name']} • ${_money.format(item['price'])}',
                    ),
                  ),
                  const Divider(),
                  Text(
                    'Người nhận: ${recipient['name']} • ${recipient['phone']}',
                  ),
                  Text('Địa chỉ: ${recipient['address']}'),
                  Text(OrderPayment.description(order)),
                  if (order['paymentTransactionId'] != null)
                    SelectableText(
                      'Mã giao dịch MoMo: ${order['paymentTransactionId']}',
                    ),
                  Text(
                    'Vận chuyển: ${_money.format(order['shippingFee'])} • Giảm: ${_money.format(order['discountAmount'])}',
                  ),
                  if (OrderPayment.isOnline(order))
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MomoPaymentScreen(orderId: id),
                        ),
                      ),
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: Text(
                        order['paymentStatus'] == 'pending'
                            ? 'Tiếp tục / kiểm tra thanh toán MoMo'
                            : 'Chi tiết thanh toán MoMo',
                      ),
                    ),
                  if (OrderPayment.canCancel(order))
                    TextButton(
                      onPressed: _busy.contains(id) ? null : () => _cancel(id),
                      child: Text(
                        _busy.contains(id) ? 'Đang hủy…' : 'Hủy đơn hàng',
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}
