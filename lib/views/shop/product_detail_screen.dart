import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../../providers/cart_provider.dart';
import '../cart/cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final cart = context.watch<CartProvider>();
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              p.imageUrl,
              height: 280,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 180,
                child: Icon(Icons.shopping_bag, size: 80),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            p.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            money.format(p.price),
            style: const TextStyle(
              fontSize: 24,
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (p.originalPrice > p.price)
            Text(
              money.format(p.originalPrice),
              style: const TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Colors.grey,
              ),
            ),
          Text('Quy cách: ${p.weight} • Tồn kho: ${p.stock}'),
          const SizedBox(height: 20),
          Text(
            p.description,
            style: const TextStyle(fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              IconButton(
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_quantity', style: const TextStyle(fontSize: 20)),
              IconButton(
                onPressed: _quantity < p.stock && _quantity < 99
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: p.stock == 0 || cart.busy
                ? null
                : () {
                    final ok = cart.addItem(p, quantity: _quantity);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Đã thêm vào giỏ hàng.'
                              : cart.error ?? 'Chưa thể thêm sản phẩm.',
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(p.stock == 0 ? 'HẾT HÀNG' : 'THÊM VÀO GIỎ'),
          ),
        ],
      ),
    );
  }
}
