import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/cart_provider.dart';
import '../../services/firebase_mock_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _voucherController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  void _handleCheckout(BuildContext context, CartProvider cart) {
    if (cart.items.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF4ECDC4)),
            SizedBox(width: 8),
            Text('Xác Nhận Đặt Hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số lượng: ${cart.itemCount} sản phẩm'),
            const SizedBox(height: 6),
            Text(
              'Tổng thanh toán: ${_currencyFormat.format(cart.totalAmount)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF6B6B), fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('Hình thức thanh toán: Thanh toán khi nhận hàng (COD)'),
            const SizedBox(height: 6),
            const Text('Địa chỉ: 475A Điện Biên Phủ, P.25, Bình Thạnh, TP.HCM'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              
              // Gọi Firebase lưu đơn hàng
              final orderId = await FirebaseService.instance.createOrder({
                'items': cart.items.values.map((i) => i.toJson()).toList(),
                'totalAmount': cart.totalAmount,
                'status': 'Chờ lấy hàng',
              });

              cart.clearCart();

              if (!mounted) return;
              showDialog(
                context: context,
                builder: (sCtx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('🎉 Đặt Hàng Thành Công!'),
                  content: Text('Mã đơn hàng của bạn: $orderId\nĐơn hàng đã được lưu đồng bộ lên Firebase.'),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(sCtx).pop(),
                      child: const Text('Xong'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('ĐỒNG Ý'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giỏ Hàng Của Bạn'),
        actions: [
          if (cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Dọn giỏ hàng?'),
                    content: const Text('Bạn có chắc muốn xóa tất cả sản phẩm khỏi giỏ?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Không')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () {
                          cart.clearCart();
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Xóa hết'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'Giỏ hàng của bạn đang trống!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text('Hãy chọn các món đồ chơi, thức ăn ngon cho bé cưng nhé.'),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items.values.toList()[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  item.imageUrl,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 70,
                                    height: 70,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.pets, color: Colors.grey),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _currencyFormat.format(item.price),
                                      style: const TextStyle(
                                        color: Color(0xFFFF6B6B),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                                    onPressed: () => cart.decrementItem(item.id),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 22, color: Color(0xFFFF6B6B)),
                                    onPressed: () => cart.incrementItem(item.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Voucher Input & Summary Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Voucher box
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _voucherController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                hintText: 'Nhập mã giảm giá: PAWPALS10',
                                prefixIcon: Icon(Icons.confirmation_number_outlined),
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4ECDC4),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onPressed: () {
                              final success = cart.applyVoucher(_voucherController.text);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? 'Áp dụng mã giảm giá thành công (-10%)!' : 'Mã giảm giá không hợp lệ!'),
                                  backgroundColor: success ? const Color(0xFF4ECDC4) : Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: const Text('Áp dụng'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tính toán
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tạm tính:', style: TextStyle(color: Colors.grey)),
                          Text(_currencyFormat.format(cart.subtotal)),
                        ],
                      ),
                      if (cart.discountAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Mã giảm giá (${cart.appliedVoucher}):', style: const TextStyle(color: Color(0xFF4ECDC4))),
                            Text('- ${_currencyFormat.format(cart.discountAmount)}', style: const TextStyle(color: Color(0xFF4ECDC4), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Phí vận chuyển:', style: TextStyle(color: Colors.grey)),
                          Text(cart.shippingFee == 0 ? 'Miễn phí' : _currencyFormat.format(cart.shippingFee)),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tổng thanh toán:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            _currencyFormat.format(cart.totalAmount),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF6B6B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _handleCheckout(context, cart),
                          child: const Text('TIẾN HÀNH ĐẶT HÀNG'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
