import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../services/checkout_pricing.dart';

class CartProvider with ChangeNotifier {
  final String? uid;
  CartProvider({this.uid});
  final Map<String, CartItem> _items = {};
  final Map<String, int> _stock = {};
  String? _appliedVoucher, _checkoutId;
  bool busy = false;
  Future<void> _writes = Future.value();
  String? error;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String get _key => 'cart_v2_$uid';
  Map<String, CartItem> get items => Map.unmodifiable(_items);
  int get itemCount => _items.values.fold(0, (s, i) => s + i.quantity);
  double get subtotal =>
      _items.values.fold(0.0, (s, i) => s + i.price * i.quantity);
  double get discountAmount =>
      CheckoutPricing.discount(subtotal, _appliedVoucher);
  double get shippingFee => CheckoutPricing.shipping(subtotal, _appliedVoucher);
  double get totalAmount => subtotal - discountAmount + shippingFee;
  String? get appliedVoucher => _appliedVoucher;
  Future<void> load() async {
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _items.clear();
      _stock.clear();
      for (final row in data['items'] as List) {
        final item = CartItem.fromJson(Map<String, dynamic>.from(row));
        if (item.quantity > 0 && item.quantity <= 99 && _items.length < 5) {
          _items[item.id] = item;
        }
      }
      _stock.addAll(Map<String, int>.from(data['stock'] as Map));
      _appliedVoucher = data['voucher'] as String?;
      _checkoutId = data['checkoutId'] as String?;
    } catch (_) {
      _items.clear();
      _stock.clear();
      _appliedVoucher = null;
      _checkoutId = null;
      await prefs.remove(_key);
    }
    notifyListeners();
  }

  void _persist() {
    if (uid == null) return;
    final raw = jsonEncode({
      'items': _items.values.map((i) => i.toJson()).toList(),
      'stock': _stock,
      'voucher': _appliedVoucher,
      'checkoutId': _checkoutId,
    });
    _writes = _writes.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, raw);
    });
  }

  void _changed() {
    _checkoutId = null;
    error = null;
    _persist();
    notifyListeners();
  }

  bool addItem(Product product, {int quantity = 1}) {
    if (busy) return false;
    final newQuantity = (_items[product.id]?.quantity ?? 0) + quantity;
    if (quantity < 1 ||
        newQuantity > product.stock ||
        newQuantity > 99 ||
        (!_items.containsKey(product.id) && _items.length >= 5)) {
      error = 'Số lượng vượt tồn kho hoặc giới hạn 5 loại sản phẩm/đơn.';
      notifyListeners();
      return false;
    }
    _stock[product.id] = product.stock;
    _items[product.id] = CartItem(
      id: product.id,
      name: product.name,
      price: product.price,
      quantity: newQuantity,
      imageUrl: product.imageUrl,
    );
    _changed();
    return true;
  }

  void incrementItem(String id) {
    if (busy || !_items.containsKey(id)) return;
    final old = _items[id]!;
    if (old.quantity >= (_stock[id] ?? 99) || old.quantity >= 99) {
      error = 'Đã đạt số lượng tồn kho.';
      notifyListeners();
      return;
    }
    _items[id] = old.copyWith(quantity: old.quantity + 1);
    _changed();
  }

  void decrementItem(String id) {
    if (busy || !_items.containsKey(id)) return;
    if (_items[id]!.quantity <= 1) {
      removeItem(id);
      return;
    }
    _items[id] = _items[id]!.copyWith(quantity: _items[id]!.quantity - 1);
    _changed();
  }

  void removeItem(String id) {
    if (busy) return;
    _items.remove(id);
    _stock.remove(id);
    _changed();
  }

  void clearCart() {
    _items.clear();
    _stock.clear();
    _appliedVoucher = null;
    _changed();
  }

  bool applyVoucher(String code) {
    if (busy) return false;
    final clean = code.trim().toUpperCase();
    if (!CheckoutPricing.vouchers.contains(clean)) return false;
    _appliedVoucher = clean;
    _changed();
    return true;
  }

  void removeVoucher() {
    if (!busy) {
      _appliedVoucher = null;
      _changed();
    }
  }

  void refreshProducts(List<Product> products) {
    if (busy) return;
    final byId = {for (final p in products) p.id: p};
    for (final id in _items.keys.toList()) {
      final product = byId[id];
      if (product == null || product.stock == 0) {
        _items.remove(id);
        _stock.remove(id);
        continue;
      }
      _items[id] = _items[id]!.copyWith(
        price: product.price,
        quantity: _items[id]!.quantity.clamp(1, product.stock),
        name: product.name,
        imageUrl: product.imageUrl,
      );
      _stock[id] = product.stock;
    }
    // Preserve a persisted retry ID after an ambiguous network failure.
    // Explicit user edits still start a new checkout.
    error = null;
    _persist();
    notifyListeners();
  }

  Future<String> beginCheckout(String Function() generateId) async {
    busy = true;
    _checkoutId ??= generateId();
    _persist();
    notifyListeners();
    await _writes;
    return _checkoutId!;
  }

  void endCheckout() {
    busy = false;
    notifyListeners();
  }

  // Use only after the server has confirmed that this attempt failed.
  void resetFailedCheckout() {
    _checkoutId = null;
    _persist();
    notifyListeners();
  }
}
