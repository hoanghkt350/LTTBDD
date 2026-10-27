import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  String? _appliedVoucher;
  double _discountPercentage = 0.0;

  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      _items.values.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  double get discountAmount => subtotal * _discountPercentage;

  double get shippingFee => subtotal > 300000 || subtotal == 0 ? 0.0 : 25000.0;

  double get totalAmount => (subtotal - discountAmount + shippingFee).clamp(0.0, double.infinity);

  String? get appliedVoucher => _appliedVoucher;

  void addItem(Product product, {int quantity = 1}) {
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (existing) => existing.copyWith(quantity: existing.quantity + quantity),
      );
    } else {
      _items.putIfAbsent(
        product.id,
        () => CartItem(
          id: product.id,
          name: product.name,
          price: product.price,
          quantity: quantity,
          imageUrl: product.imageUrl,
        ),
      );
    }
    notifyListeners();
  }

  void incrementItem(String productId) {
    if (_items.containsKey(productId)) {
      _items.update(
        productId,
        (existing) => existing.copyWith(quantity: existing.quantity + 1),
      );
      notifyListeners();
    }
  }

  void decrementItem(String productId) {
    if (!_items.containsKey(productId)) return;

    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existing) => existing.copyWith(quantity: existing.quantity - 1),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _appliedVoucher = null;
    _discountPercentage = 0.0;
    notifyListeners();
  }

  bool applyVoucher(String code) {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode == "PAWPALS10" || cleanCode == "HUTECH10") {
      _appliedVoucher = cleanCode;
      _discountPercentage = 0.10; // Giảm 10%
      notifyListeners();
      return true;
    } else if (cleanCode == "FREESHIP") {
      _appliedVoucher = cleanCode;
      _discountPercentage = 0.05;
      notifyListeners();
      return true;
    }
    return false;
  }
}
