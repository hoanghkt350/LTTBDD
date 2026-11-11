import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/app_error.dart';
import '../../services/online_payment_service.dart';
import '../../services/order_payment.dart';
import '../profile/orders_screen.dart';

class MomoPaymentScreen extends StatefulWidget {
  const MomoPaymentScreen({
    super.key,
    required this.orderId,
    this.initialSession,
    this.service,
  });

  final String orderId;
  final PaymentSession? initialSession;
  final OnlinePaymentService? service;

  @override
  State<MomoPaymentScreen> createState() => _MomoPaymentScreenState();
}

class _MomoPaymentScreenState extends State<MomoPaymentScreen>
    with WidgetsBindingObserver {
  late final OnlinePaymentService _service;
  late final Stream<Map<String, dynamic>?> _order;
  bool _opening = false, _checking = false;
  String? _error, _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = widget.service ?? OnlinePaymentService();
    _order = _service.watchOrder(widget.orderId);
    final session = widget.initialSession;
    if (session?.paymentUrl != null && session?.paymentStatus == 'pending') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(session));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _open([PaymentSession? initial]) async {
    if (!mounted || _opening || _checking) return;
    setState(() {
      _opening = true;
      _error = null;
      _notice = null;
    });
    try {
      final session = initial ?? await _service.create(widget.orderId);
      if (!mounted) return;
      if (session.paymentStatus == 'pending' && session.paymentUrl != null) {
        await _service.open(session);
      } else if (session.paymentStatus == 'pending') {
        setState(
          () => _notice = 'MoMo chưa trả về đường dẫn thanh toán. Đơn hàng đã được lưu; hãy kiểm tra trạng thái hoặc thử mở MoMo lại sau.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _check() async {
    if (!mounted || _checking || _opening) return;
    setState(() {
      _checking = true;
      _error = null;
      _notice = null;
    });
    try {
      final session = await _service.check(widget.orderId);
      if (mounted && session.paymentStatus == 'pending') {
        setState(
          () => _notice = 'Đơn hàng chưa được xác nhận thanh toán. Nếu đã trả tiền, vui lòng chờ MoMo cập nhật và kiểm tra lại.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thanh toán MoMo')),
    body: StreamBuilder<Map<String, dynamic>?>(
      stream: _order,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(errorMessage(snapshot.error!)),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final order = snapshot.data;
        if (order == null || !OrderPayment.isOnline(order)) {
          return const Center(
            child: Text('Không tìm thấy đơn thanh toán MoMo.'),
          );
        }
        final status = order['paymentStatus'] as String? ?? 'pending';
        final sandbox = order['paymentEnvironment'] == 'sandbox';
        final pending = status == 'pending';
        final paid = status == 'paid';
        final busy = _opening || _checking;
        final money = NumberFormat.currency(
          locale: 'vi_VN',
          symbol: 'đ',
          decimalDigits: 0,
        );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (sandbox)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Môi trường thử nghiệm MoMo. Không thu tiền thật và không giao hàng cho đơn thử nghiệm.',
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Icon(
              paid
                  ? Icons.check_circle_outline
                  : pending
                  ? Icons.account_balance_wallet_outlined
                  : Icons.info_outline,
              size: 64,
              color: paid
                  ? Colors.green
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              paid && sandbox
                  ? 'Thanh toán thử nghiệm thành công'
                  : paid
                  ? 'Đã thanh toán MoMo'
                  : status == 'failed'
                  ? 'Thanh toán không thành công'
                  : status == 'review_required'
                  ? 'Cần cửa hàng đối soát'
                  : 'Chờ thanh toán MoMo',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              money.format(order['totalAmount'] ?? 0),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            SelectableText('Mã đơn: ${widget.orderId}'),
            if (order['paymentTransactionId'] != null)
              SelectableText(
                'Mã giao dịch MoMo: ${order['paymentTransactionId']}',
              ),
            const SizedBox(height: 16),
            Text(
              paid
                  ? sandbox
                        ? 'Giao dịch thử đã được xác minh. Tồn kho của đơn thử nghiệm đã được hoàn lại.'
                        : 'Cửa hàng đã nhận kết quả thanh toán và sẽ xử lý đơn hàng của bạn.'
                  : status == 'failed'
                  ? 'MoMo xác nhận giao dịch không thành công. Đơn đã hủy và hàng đã được hoàn kho. Bạn có thể đặt đơn mới.'
                  : status == 'review_required'
                  ? 'MoMo ghi nhận tiền sau khi đơn đã kết thúc. Vui lòng liên hệ cửa hàng kèm mã đơn và mã giao dịch để đối soát hoặc hoàn tiền.'
                  : 'Mở MoMo để thanh toán. Khi quay lại PawPals, ứng dụng sẽ kiểm tra kết quả. Bạn cũng có thể xem lại đơn này trong lịch sử đơn hàng.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 16),
              Text(_notice!),
            ],
            const SizedBox(height: 24),
            if (pending) ...[
              FilledButton.icon(
                onPressed: busy ? null : () => _open(),
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  _opening ? 'Đang mở MoMo…' : 'Mở MoMo để thanh toán',
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : _check,
                icon: const Icon(Icons.refresh),
                label: Text(
                  _checking ? 'Đang kiểm tra…' : 'Kiểm tra thanh toán',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nếu muốn hủy thanh toán, hãy chọn hủy trên MoMo. Đơn chỉ được xác nhận thất bại sau khi có kết quả từ MoMo.',
              ),
            ],
            TextButton(
              onPressed: busy
                  ? null
                  : () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const OrdersScreen()),
                    ),
              child: const Text('Xem đơn hàng của tôi'),
            ),
          ],
        );
      },
    ),
  );
}
