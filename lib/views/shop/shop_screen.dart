import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/care_widgets.dart';

import '../../providers/shop_provider.dart';
import '../../providers/cart_provider.dart';
import '../cart/cart_screen.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final cart = context.watch<CartProvider>();
    const categories = {
      'ALL': 'Tất cả',
      'FOOD': 'Thức ăn',
      'ACCESSORY': 'Phụ kiện',
      'TOY': 'Đồ chơi',
      'HEALTH': 'Sức khỏe',
      'HYGIENE': 'Vệ sinh',
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cửa hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: shop.isLoading ? null : shop.fetchProducts,
          ),
          IconButton(
            tooltip: 'Giỏ hàng (${cart.itemCount})',
            icon: Badge(
              label: Text('${cart.itemCount}'),
              isLabelVisible: cart.itemCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              initialValue: shop.searchQuery,
              decoration: const InputDecoration(
                labelText: 'Tìm sản phẩm',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: shop.setSearchQuery,
            ),
          ),
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: categories.entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: shop.selectedCategory == e.key,
                        onSelected: (_) => shop.setCategory(e.key),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (shop.isLoading) const LinearProgressIndicator(),
          if (shop.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                shop.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: shop.products.isEmpty
                ? const SingleChildScrollView(
                    padding: EdgeInsets.all(22),
                    child: CareEmptyState(
                      icon: Icons.search_rounded,
                      title: 'Tìm món đồ bé yêu thích',
                      message: 'Chưa có sản phẩm phù hợp. Thử từ khóa hoặc danh mục khác nhé.',
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, box) => GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: (box.maxWidth / 170).floor().clamp(
                          1,
                          5,
                        ),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 310,
                      ),
                      itemCount: shop.products.length,
                      itemBuilder: (context, index) =>
                          ProductCard(product: shop.products[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
