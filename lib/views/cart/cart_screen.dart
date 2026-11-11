import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/app_error.dart';
import '../../services/online_payment_service.dart';
import '../../services/order_payment.dart';
import '../profile/orders_screen.dart';
import 'momo_payment_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _form = GlobalKey<FormState>();
  final _voucher = TextEditingController(),
      _name = TextEditingController(),
      _phone = TextEditingController(),
      _address = TextEditingController();
  final _money = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );
  bool _refreshing = false;
  String _paymentMethod = OrderPayment.cod;
  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _name.text = user.displayName;
    _phone.text = user.phoneNumber ?? '';
    _address.text = user.address ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    for (final c in [_voucher, _name, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted || _refreshing || context.read<CartProvider>().busy) return;
    setState(() => _refreshing = true);
    final cart = context.read<CartProvider>();
    try {
      final products = await FirebaseService.instance.getProducts();
      if (mounted) cart.refreshProducts(products);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _checkout() async {
    final cart = context.read<CartProvider>();
    if (cart.busy || cart.items.isEmpty || !_form.currentState!.validate()) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _paymentMethod == OrderPayment.momo
              ? 'Đặt hàng và thanh toán MoMo'
              : 'Xác nhận đặt hàng COD',
        ),
        content: Text(
          'Tổng dự kiến: ${_money.format(cart.totalAmount)}\nGiao đến: ${_address.text.trim()}\n${_paymentMethod == OrderPayment.momo ? 'Tiếp tục thanh toán qua MoMo.' : 'Thanh toán khi nhận hàng.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đặt hàng'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || cart.busy) return;
    final shop = context.read<ShopProvider>();
    try {
      final id = await cart.beginCheckout(
        () => FirebaseService.instance.firestore.collection('orders').doc().id,
      );
      final checkout = <String, dynamic>{
        'quantities': {
          for (final item in cart.items.values) item.id: item.quantity,
        },
        'prices': {for (final item in cart.items.values) item.id: item.price},
        'voucher': cart.appliedVoucher,
        'recipient': {
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
          'address': _address.text.trim(),
        },
      };
      if (_paymentMethod == OrderPayment.momo) {
        final session = await OnlinePaymentService().create(
          id,
          checkout: checkout,
        );
        if (session.paymentStatus == 'failed') {
          cart.resetFailedCheckout();
          throw StateError(
            'MoMo chưa tạo được thanh toán. Giỏ hàng được giữ lại; bạn có thể chọn COD hoặc thử lại sau.',
          );
        }
        cart.clearCart();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MomoPaymentScreen(orderId: id, initialSession: session),
          ),
        );
        return;
      }
      await FirebaseService.instance.createOrder(checkout, orderId: id);
      cart.clearCart();
      await shop.fetchProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu đơn hàng $id. Thanh toán khi nhận hàng.'),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OrdersScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      cart.endCheckout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final disabled = cart.busy || _refreshing;
    return PopScope(
      canPop: !cart.busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Giỏ hàng'),
          actions: [
            IconButton(
              tooltip: 'Cập nhật giá và tồn kho',
              onPressed: disabled ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: cart.items.isEmpty
            ? const Center(
                child: Text(
                  'Giỏ hàng trống. Hãy chọn sản phẩm trong cửa hàng.',
                ),
              )
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (disabled) const LinearProgressIndicator(),
                    if (cart.error != null)
                      Text(
                        cart.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ...cart.items.values.map(
                      (item) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(_money.format(item.price)),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: disabled
                                        ? null
                                        : () => cart.decrementItem(item.id),
                                    icon: const Icon(Icons.remove),
                                  ),
                                  Text('${item.quantity}'),
                                  IconButton(
                                    onPressed: disabled
                                        ? null
                                        : () => cart.incrementItem(item.id),
                                    icon: const Icon(Icons.add),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: disabled
                                        ? null
                                        : () => cart.removeItem(item.id),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Thông tin nhận hàng',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      enabled: !disabled,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Họ tên người nhận',
                      ),
                      validator: (v) => (v?.trim().isNotEmpty ?? false)
                          ? null
                          : 'Nhập họ tên',
                    ),
                    TextFormField(
                      controller: _phone,
                      enabled: !disabled,
                      keyboardType: TextInputType.phone,
                      maxLength: 13,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                      ),
                      validator: (v) =>
                          RegExp(r'^\+?[0-9]{9,12}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Số điện thoại không hợp lệ',
                    ),
                    TextFormField(
                      controller: _address,
                      enabled: !disabled,
                      maxLength: 300,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ giao hàng',
                      ),
                      validator: (v) => (v?.trim().length ?? 0) >= 8
                          ? null
                          : 'Nhập địa chỉ đầy đủ',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _voucher,
                            enabled: !disabled,
                            decoration: const InputDecoration(
                              labelText: 'Mã ưu đãi',
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: disabled
                              ? null
                              : () {
                                  final ok = cart.applyVoucher(_voucher.text);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Đã áp dụng ưu đãi.'
                                            : 'Mã không hợp lệ.',
                                      ),
                                    ),
                                  );
                                },
                          child: const Text('Áp dụng'),
                        ),
                      ],
                    ),
                    if (cart.appliedVoucher != null)
                      ListTile(
                        title: Text('Mã: ${cart.appliedVoucher}'),
                        trailing: IconButton(
                          onPressed: disabled ? null : cart.removeVoucher,
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text('Tạm tính: ${_money.format(cart.subtotal)}'),
                    Text('Giảm giá: -${_money.format(cart.discountAmount)}'),
                    Text('Vận chuyển: ${_money.format(cart.shippingFee)}'),
                    const Divider(),
                    Text(
                      'Tổng: ${_money.format(cart.totalAmount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Phương thức thanh toán',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Khi nhận hàng (COD)'),
                          selected: _paymentMethod == OrderPayment.cod,
                          onSelected: disabled
                              ? null
                              : (_) => setState(
                                  () => _paymentMethod = OrderPayment.cod,
                                ),
                        ),
                        ChoiceChip(
                          label: const Text('Ví MoMo'),
                          selected: _paymentMethod == OrderPayment.momo,
                          onSelected: disabled
                              ? null
                              : (_) => setState(
                                  () => _paymentMethod = OrderPayment.momo,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _paymentMethod == OrderPayment.momo
                          ? 'Mở MoMo để thanh toán và quay lại PawPals xem kết quả.'
                          : 'Thanh toán cho người giao hàng khi nhận sản phẩm.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: disabled ? null : _checkout,
                      child: Text(
                        cart.busy
                            ? 'Đang xác nhận đơn hàng…'
                            : _paymentMethod == OrderPayment.momo
                            ? 'ĐẶT HÀNG • THANH TOÁN MOMO'
                            : 'ĐẶT HÀNG • THANH TOÁN KHI NHẬN',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Miễn phí vận chuyển từ 300.000đ hoặc với mã FREESHIP. Mã PAWPALS10 và HUTECH10 giảm 10% tiền hàng.',
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
