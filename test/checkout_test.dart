import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pawpals_app/providers/cart_provider.dart';
import 'package:pawpals_app/models/product_model.dart';

Product product(String id, {int stock = 10, double price = 100000}) => Product(
  id: id,
  name: id,
  category: 'FOOD',
  petTarget: 'DOG',
  price: price,
  originalPrice: price,
  stock: stock,
  imageUrl: 'https://example.com/p.jpg',
  description: 'Test',
);

void main() {
  test('FREESHIP removes shipping without discounting items', () {
    final cart = CartProvider()..addItem(product('p1'));
    expect(cart.shippingFee, 25000);
    expect(cart.applyVoucher('FREESHIP'), isTrue);
    expect(cart.shippingFee, 0);
    expect(cart.discountAmount, 0);
    expect(cart.totalAmount, 100000);
  });
  test('shipping is free exactly at 300000', () {
    final cart = CartProvider()..addItem(product('p1'), quantity: 3);
    expect(cart.shippingFee, 0);
  });
  test('quantity is bounded by stock, including repeat additions', () {
    final cart = CartProvider();
    expect(cart.addItem(product('p1', stock: 2), quantity: 2), isTrue);
    expect(cart.addItem(product('p1', stock: 2)), isFalse);
    cart.incrementItem('p1');
    expect(cart.itemCount, 2);
    expect(cart.addItem(product('empty', stock: 0)), isFalse);
    expect(cart.addItem(product('bad'), quantity: -1), isFalse);
  });
  test('checkout locks cart changes', () async {
    final cart = CartProvider()..addItem(product('p1'));
    await cart.beginCheckout(() => 'order1');
    cart.incrementItem('p1');
    cart.removeItem('p1');
    expect(cart.itemCount, 1);
    expect(cart.addItem(product('p2')), isFalse);
    cart.endCheckout();
    cart.removeItem('p1');
    expect(cart.itemCount, 0);
  });
  test(
    'cart and checkout retry ID survive reload and are isolated by UID',
    () async {
      SharedPreferences.setMockInitialValues({});
      final original = CartProvider(uid: 'alice')..addItem(product('p1'));
      final id = await original.beginCheckout(() => 'stable-id');
      original.endCheckout();
      final restored = CartProvider(uid: 'alice');
      await restored.load();
      expect(restored.itemCount, 1);
      expect(await restored.beginCheckout(() => 'wrong-id'), id);
      restored.endCheckout();
      final other = CartProvider(uid: 'bob');
      await other.load();
      expect(other.itemCount, 0);
    },
  );
}
