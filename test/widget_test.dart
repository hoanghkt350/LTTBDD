import 'package:flutter_test/flutter_test.dart';
import 'package:pawpals_app/models/pet_model.dart';
import 'package:pawpals_app/models/product_model.dart';
import 'package:pawpals_app/providers/cart_provider.dart';

void main() {
  group('Kiểm thử Đồ án PawPals (HUTECH CMP177)', () {
    test('1. Kiểm thử Model Pet (SQFlite Database)', () {
      final pet = Pet(
        id: 1,
        name: 'Milo',
        species: 'DOG',
        breed: 'Golden Retriever',
        gender: 'Đực',
        birthDate: '2023-04-12',
        weight: 24.5,
        microchipId: 'CHIP-9821',
      );

      expect(pet.name, 'Milo');
      expect(pet.species, 'DOG');
      expect(pet.weight, 24.5);

      final map = pet.toMap();
      expect(map['name'], 'Milo');
      expect(map['weight'], 24.5);

      final petFromMap = Pet.fromMap(map);
      expect(petFromMap.name, pet.name);
      expect(petFromMap.breed, pet.breed);
    });

    test('2. Kiểm thử Model Product (Cloud Firestore)', () {
      final product = Product(
        id: 'prod_01',
        name: 'Thức Ăn Hạt Royal Canin',
        category: 'FOOD',
        petTarget: 'DOG',
        price: 395000,
        originalPrice: 460000,
        stock: 35,
        imageUrl: 'https://example.com/food.png',
        description: 'Thức ăn cao cấp cho chó',
      );

      expect(product.id, 'prod_01');
      expect(product.price, 395000);

      final map = product.toMap();
      expect(map['price'], 395000);

      final productFromMap = Product.fromMap(map);
      expect(productFromMap.name, product.name);
    });

    test('3. Kiểm thử Giỏ hàng CartProvider & Voucher (State Management)', () {
      final cart = CartProvider();
      expect(cart.itemCount, 0);
      expect(cart.subtotal, 0.0);

      final product1 = Product(
        id: 'prod_01',
        name: 'Thức Ăn Hạt',
        category: 'FOOD',
        petTarget: 'DOG',
        price: 100000,
        originalPrice: 120000,
        stock: 10,
        imageUrl: 'https://example.com/1.png',
        description: 'Mô tả 1',
      );

      final product2 = Product(
        id: 'prod_02',
        name: 'Pate Mèo',
        category: 'FOOD',
        petTarget: 'CAT',
        price: 50000,
        originalPrice: 60000,
        stock: 20,
        imageUrl: 'https://example.com/2.png',
        description: 'Mô tả 2',
      );

      // Thêm sản phẩm 1 (số lượng 2)
      cart.addItem(product1, quantity: 2);
      expect(cart.itemCount, 2);
      expect(cart.subtotal, 200000.0);

      // Thêm sản phẩm 2 (số lượng 1)
      cart.addItem(product2, quantity: 1);
      expect(cart.itemCount, 3);
      expect(cart.subtotal, 250000.0);

      // Áp dụng voucher giảm 10%
      final voucherApplied = cart.applyVoucher('PAWPALS10');
      expect(voucherApplied, true);
      expect(cart.discountAmount, 25000.0);

      // Xóa sản phẩm 1 khỏi giỏ
      cart.removeItem('prod_01');
      expect(cart.itemCount, 1);
      expect(cart.subtotal, 50000.0);

      // Xóa sạch giỏ hàng
      cart.clearCart();
      expect(cart.itemCount, 0);
      expect(cart.subtotal, 0.0);
    });
  });
}
