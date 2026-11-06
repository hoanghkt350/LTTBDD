import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';
import '../models/user_model.dart';
import 'checkout_pricing.dart';

class FirebaseService {
  static final instance = FirebaseService._();
  FirebaseService._();
  static bool isFirebaseInitialized = false;
  static String? initializationError;
  static FirebaseApp? _app;
  fb.FirebaseAuth get auth {
    _ensureReady();
    return fb.FirebaseAuth.instanceFor(app: _app!);
  }

  FirebaseFirestore get firestore {
    _ensureReady();
    return FirebaseFirestore.instanceFor(app: _app!);
  }

  void _ensureReady() {
    if (!isFirebaseInitialized) {
      throw StateError(
        'Chưa kết nối Firebase. Hãy cấu hình project thật theo README.',
      );
    }
  }

  String get uid {
    final user = auth.currentUser;
    if (user == null) throw StateError('Bạn cần đăng nhập lại.');
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get userDocument =>
      firestore.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> userCollection(String name) =>
      userDocument.collection(name);

  static Future<void> initialize() async {
    try {
      const emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
      if (emulatorHost.isNotEmpty && !kDebugMode) {
        throw StateError('Firebase Emulator chỉ dành cho bản debug.');
      }
      final app =
          await (emulatorHost.isEmpty
                  ? Firebase.initializeApp()
                  : Firebase.initializeApp(
                      name: 'pawpals-emulator',
                      options: const FirebaseOptions(
                        apiKey: 'demo-pawpals-key',
                        appId: '1:123456789:android:1234567890abcdef',
                        messagingSenderId: '123456789',
                        projectId: 'demo-pawpals',
                      ),
                    ))
              .timeout(const Duration(seconds: 15));
      _app = app;
      if (app.options.apiKey.contains('Example')) {
        throw StateError(
          'google-services.json đang chứa API key mẫu. Hãy thay bằng file từ Firebase Console và build lại.',
        );
      }
      isFirebaseInitialized = true;
      initializationError = null;
      if (emulatorHost.isNotEmpty) {
        const authPort = int.fromEnvironment(
          'FIREBASE_AUTH_EMULATOR_PORT',
          defaultValue: 9099,
        );
        const firestorePort = int.fromEnvironment(
          'FIRESTORE_EMULATOR_PORT',
          defaultValue: 8080,
        );
        await instance.auth.useAuthEmulator(emulatorHost, authPort);
        instance.firestore.useFirestoreEmulator(emulatorHost, firestorePort);
      }
    } catch (e) {
      initializationError = e.toString();
      isFirebaseInitialized = false;
      debugPrint('Firebase: $e');
    }
  }

  AppUser profileFromAuth(fb.User user) => AppUser(
    uid: user.uid,
    email: user.email ?? '',
    displayName: user.displayName ?? user.email?.split('@').first ?? 'Chủ nuôi',
    phoneNumber: user.phoneNumber,
    avatarUrl: user.photoURL,
  );
  Future<AppUser> getProfile(fb.User user) async {
    final snapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .get()
        .timeout(const Duration(seconds: 12));
    return snapshot.exists
        ? AppUser.fromJson({...snapshot.data()!, 'uid': user.uid})
        : profileFromAuth(user);
  }

  Future<AppUser> signInWithEmail(String email, String password) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return getProfile(credential.user!);
  }

  Future<AppUser> register(String name, String email, String password) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user!.updateDisplayName(name);
    final user = profileFromAuth(credential.user!).copyWith(displayName: name);
    await saveProfile(user);
    return user;
  }

  Future<void> saveProfile(AppUser user) async {
    if (user.uid != uid) throw StateError('Tài khoản không hợp lệ.');
    await userDocument.set(user.toJson()).timeout(const Duration(seconds: 15));
    await auth.currentUser!.updateDisplayName(user.displayName);
  }

  Future<void> resetPassword(String email) =>
      auth.sendPasswordResetEmail(email: email);

  Future<List<Product>> getProducts({String? category, String? query}) async {
    final snapshot = await firestore
        .collection('products')
        .get()
        .timeout(const Duration(seconds: 12));
    var products = snapshot.docs
        .map((d) => Product.fromMap({...d.data(), 'id': d.id}))
        .toList();
    if (category != null && category != 'ALL') {
      products = products.where((p) => p.category == category).toList();
    }
    final search = query?.trim().toLowerCase() ?? '';
    if (search.isNotEmpty) {
      products = products
          .where(
            (p) =>
                p.name.toLowerCase().contains(search) ||
                p.description.toLowerCase().contains(search),
          )
          .toList();
    }
    return products;
  }

  // A Firestore transaction validates current prices and reserves stock atomically.
  // The order ID is supplied by the caller and reused on retry to avoid duplicates.
  Future<String> createOrder(
    Map<String, dynamic> data, {
    required String orderId,
  }) async {
    final owner = uid;
    final ref = firestore.collection('orders').doc(orderId);
    final input = Map<String, int>.from(data['quantities'] as Map);
    if (input.isEmpty ||
        input.length > 5 ||
        input.values.any((q) => q < 1 || q > 99)) {
      throw StateError('Mỗi đơn tối đa 5 loại sản phẩm, mỗi loại từ 1 đến 99.');
    }
    final voucher = data['voucher'] as String? ?? '';
    if (voucher.isNotEmpty && !CheckoutPricing.vouchers.contains(voucher)) {
      throw StateError('Mã giảm giá không hợp lệ.');
    }
    final recipient = Map<String, dynamic>.from(data['recipient'] as Map);
    if ((recipient['name'] as String? ?? '').trim().isEmpty ||
        !RegExp(r'^\+?[0-9]{9,12}$')
            .hasMatch(recipient['phone'] as String? ?? '') ||
        (recipient['address'] as String? ?? '').trim().length < 8) {
      throw StateError(
        'Vui lòng nhập tên, số điện thoại và địa chỉ giao hàng hợp lệ.',
      );
    }
    return firestore.runTransaction((tx) async {
      final previous = await tx.get(ref);
      if (previous.exists) {
        if (previous.data()!['userId'] != owner) {
          throw StateError('Mã đơn không hợp lệ.');
        }
        return orderId;
      }
      final products = <String, Product>{};
      for (final id in input.keys) {
        final doc = await tx.get(firestore.collection('products').doc(id));
        if (!doc.exists) {
          throw StateError('Sản phẩm đã ngừng bán. Hãy cập nhật giỏ hàng.');
        }
        final product = Product.fromMap({...doc.data()!, 'id': id});
        if ((data['prices'] as Map?)?[id] != product.price) {
          throw StateError(
            'Giá sản phẩm đã thay đổi. Bấm cập nhật giỏ hàng trước khi đặt lại.',
          );
        }
        if (product.stock < input[id]!) {
          throw StateError(
            '${product.name} chỉ còn ${product.stock} sản phẩm.',
          );
        }
        products[id] = product;
      }
      double subtotal = 0;
      final items = <String, dynamic>{};
      for (final entry in products.entries) {
        final p = entry.value;
        final quantity = input[entry.key]!;
        subtotal += p.price * quantity;
        items[entry.key] = {
          'name': p.name,
          'price': p.price,
          'quantity': quantity,
          'imageUrl': p.imageUrl,
        };
        tx.update(firestore.collection('products').doc(entry.key), {
          'stock': p.stock - quantity,
          'lastOrderId': orderId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      final discount = CheckoutPricing.discount(subtotal, voucher);
      final shipping = CheckoutPricing.shipping(subtotal, voucher);
      tx.set(ref, {
        'orderId': orderId,
        'userId': owner,
        'items': items,
        'recipient': recipient,
        'subtotal': subtotal,
        'discountAmount': discount,
        'shippingFee': shipping,
        'totalAmount': subtotal - discount + shipping,
        'voucher': voucher,
        'status': 'Chờ xác nhận',
        'paymentMethod': 'COD',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return orderId;
    });
  }

  Stream<List<Map<String, dynamic>>> watchOrders() {
    return firestore
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) {
          final orders = s.docs
              .map((d) => {...d.data(), 'orderId': d.id})
              .toList();
          orders.sort(
            (a, b) =>
                ((b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)
                    .compareTo(
                      (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                          0,
                    ),
          );
          return orders;
        });
  }

  Future<List<Map<String, dynamic>>> getOrders() => watchOrders().first;
  Future<void> cancelOrder(String id) async {
    final owner = uid;
    final ref = firestore.collection('orders').doc(id);
    await firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists || doc.data()!['userId'] != owner) {
        throw StateError('Không tìm thấy đơn hàng.');
      }
      final order = doc.data()!;
      if (order['status'] == 'Đã hủy') return;
      if (order['status'] != 'Chờ xác nhận') {
        throw StateError('Đơn hàng đã xử lý, không thể hủy.');
      }
      final items = Map<String, dynamic>.from(order['items'] as Map);
      final stock = <String, int>{};
      for (final key in items.keys) {
        final product = await tx.get(firestore.collection('products').doc(key));
        if (!product.exists) {
          throw StateError(
            'Không thể hoàn tồn kho. Vui lòng liên hệ cửa hàng.',
          );
        }
        stock[key] = (product.data()!['stock'] as num).toInt();
      }
      for (final key in items.keys) {
        tx.update(firestore.collection('products').doc(key), {
          'stock': stock[key]! + (items[key]['quantity'] as num).toInt(),
          'lastOrderId': id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.update(ref, {
        'status': 'Đã hủy',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
