import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/product_model.dart';
import '../models/user_model.dart';
import 'checkout_pricing.dart';
import 'auth_validation.dart';
import 'email_verification.dart';

class FirebaseService {
  static final instance = FirebaseService._();
  FirebaseService._();
  static bool isFirebaseInitialized = false;
  static String? initializationError;
  static FirebaseApp? _app;
  static Future<void>? _initializing;
  Future<void>? _googleInitializing;
  static bool get supportsGoogleSignIn =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  bool get isReady => isFirebaseInitialized;
  fb.FirebaseAuth get auth {
    _ensureReady();
    return fb.FirebaseAuth.instanceFor(app: _app!);
  }

  FirebaseFirestore get firestore {
    _ensureReady();
    return FirebaseFirestore.instanceFor(app: _app!);
  }

  FirebaseFunctions get functions {
    _ensureReady();
    return FirebaseFunctions.instanceFor(app: _app!, region: 'asia-southeast1');
  }

  Future<void> requireAdmin() async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập bằng tài khoản quản trị.');
    }
    if (!await hasAdminAccess(forceRefresh: true)) {
      throw StateError('Bạn không có quyền quản trị.');
    }
  }

  Future<bool> hasAdminAccess({bool forceRefresh = false}) async {
    final user = auth.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult(forceRefresh);
    if (token.claims?['admin'] == true) return true;
    final request = await firestore
        .collection('admin_requests')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    return request.data()?['status'] == 'approved';
  }

  Stream<bool> watchAdminApproval(String uid) => firestore
      .collection('admin_requests')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .where((snapshot) => !snapshot.metadata.isFromCache)
      .map((snapshot) => snapshot.data()?['status'] == 'approved');

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

  static Future<void> initialize() {
    if (isFirebaseInitialized) return Future.value();
    return _initializing ??= _initialize();
  }

  static Future<void> _initialize() async {
    final timer = Stopwatch()..start();
    initializationError = null;
    try {
      const emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
      if (emulatorHost.isNotEmpty && !kDebugMode) {
        throw StateError('Firebase Emulator chỉ dành cho bản debug.');
      }
      // Native SDK startup can exceed 15 seconds on a busy Android emulator.
      // Keep observing its result; timing out here discards a late success and
      // leaves the app permanently on the setup screen.
      final app = await (emulatorHost.isEmpty
          ? Firebase.initializeApp()
          : Firebase.initializeApp(
              name: 'pawpals-emulator',
              options: const FirebaseOptions(
                apiKey: 'demo-pawpals-key',
                appId: '1:123456789:android:1234567890abcdef',
                messagingSenderId: '123456789',
                projectId: 'demo-pawpals',
              ),
            ));
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
        instance.functions.useFunctionsEmulator(
          emulatorHost,
          const int.fromEnvironment(
            'FIREBASE_FUNCTIONS_EMULATOR_PORT',
            defaultValue: 5001,
          ),
        );
      }
    } catch (e) {
      initializationError = e.toString();
      isFirebaseInitialized = false;
      debugPrint('Firebase: $e');
    } finally {
      _initializing = null;
      debugPrint(
        'Firebase startup: ${timer.elapsedMilliseconds} ms; ready=$isFirebaseInitialized',
      );
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

  Future<void> _createProfileIfMissing(fb.User user) async {
    final reference = firestore.collection('users').doc(user.uid);
    await firestore
        .runTransaction((transaction) async {
          final current = await transaction.get(reference);
          if (!current.exists) {
            transaction.set(reference, profileFromAuth(user).toJson());
          }
        })
        .timeout(const Duration(seconds: 12));
  }

  Future<AppUser> signInWithEmail(String email, String password) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    await _createProfileIfMissing(user);
    return getProfile(user);
  }

  Future<bool> signInWithGoogle() async {
    if (!supportsGoogleSignIn) {
      throw StateError('Đăng nhập Google hỗ trợ Android, iOS, macOS và Web.');
    }
    try {
      if (kIsWeb) {
        final provider = fb.GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        await auth.signInWithPopup(provider);
      } else {
        final google = GoogleSignIn.instance;
        try {
          await (_googleInitializing ??= google.initialize());
        } catch (_) {
          _googleInitializing = null;
          rethrow;
        }
        // Allow choosing a different account after signing out of PawPals.
        await google.signOut();
        final account = await google.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw StateError(
            'Google chưa cung cấp thông tin đăng nhập. Vui lòng thử lại.',
          );
        }
        await auth.signInWithCredential(
          fb.GoogleAuthProvider.credential(idToken: idToken),
        );
      }
      await _createProfileIfMissing(auth.currentUser!);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return false;
      }
      rethrow;
    }
  }

  Future<AppUser> register(String name, String email, String password) async {
    final passwordError = registrationPasswordError(password);
    if (passwordError != null) throw ArgumentError(passwordError);
    if (name.trim().isEmpty || name.trim().length > 80) {
      throw ArgumentError('Tên cần từ 1 đến 80 ký tự.');
    }
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user!.updateDisplayName(name.trim());
    // The auth listener opens the session and loads the user's profile.
    final profile = profileFromAuth(credential.user!)
        .copyWith(displayName: name.trim());
    await firestore
        .collection('users')
        .doc(profile.uid)
        .set(profile.toJson(), SetOptions(merge: true))
        .timeout(const Duration(seconds: 12));
    return profile;
  }

  Future<EmailVerificationDelivery?> sendVerificationCode() async {
    final result = await functions
        .httpsCallable('sendEmailVerificationCode')
        .call();
    final data = Map<String, dynamic>.from(result.data as Map);
    if (data['verified'] == true) return null;
    return EmailVerificationDelivery.fromMap(data);
  }

  Future<void> verifyEmailCode(String code) async {
    await functions.httpsCallable('verifyEmailVerificationCode').call({
      'code': code,
    });
    await refreshVerification();
  }

  Future<void> sendVerificationLink() async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Bạn cần đăng nhập lại.');
    await auth.setLanguageCode('vi');
    await user.sendEmailVerification();
  }

  Future<void> refreshVerification() async {
    await auth.currentUser?.reload();
    final user = auth.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError(
        'Email chưa được xác nhận. Vui lòng nhập mã trong email.',
      );
    }
    // Firestore rules evaluate the ID token; reload alone does not refresh it.
    await user.getIdToken(true);
    final snapshot = await userDocument.get();
    if (!snapshot.exists) await saveProfile(profileFromAuth(user));
  }

  Future<void> saveProfile(AppUser user) async {
    if (user.uid != uid) throw StateError('Tài khoản không hợp lệ.');
    await userDocument.set(user.toJson()).timeout(const Duration(seconds: 15));
    await auth.currentUser!.updateDisplayName(user.displayName);
  }

  Future<void> resetPassword(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      // Keep the same result whether the email exists or not.
      if (e.code != 'user-not-found') rethrow;
    }
  }

  Future<List<Product>> getProducts({String? category, String? query}) async {
    final snapshot = await firestore
        .collection('products')
        .get()
        .timeout(const Duration(seconds: 12));
    var products = snapshot.docs
        .where((d) => d.data()['isActive'] != false)
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
        if (previous.data()!['paymentMethod'] != 'COD') {
          throw StateError(
            'Đơn này đã chọn thanh toán online. Hãy kiểm tra lịch sử đơn hàng.',
          );
        }
        return orderId;
      }
      final products = <String, Product>{};
      for (final id in input.keys) {
        final doc = await tx.get(firestore.collection('products').doc(id));
        if (!doc.exists) {
          throw StateError('Sản phẩm đã ngừng bán. Hãy cập nhật giỏ hàng.');
        }
        if (doc.data()!['isActive'] == false) {
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
  Future<void> cancelOrder(String id, {bool asAdmin = false}) async {
    if (asAdmin) await requireAdmin();
    final owner = uid;
    final ref = firestore.collection('orders').doc(id);
    await firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists || (!asAdmin && doc.data()!['userId'] != owner)) {
        throw StateError('Không tìm thấy đơn hàng.');
      }
      final order = doc.data()!;
      if (order['paymentMethod'] == 'MOMO') {
        throw StateError(
          'Đơn MoMo được xử lý theo kết quả thanh toán. Nếu đã trả tiền, vui lòng liên hệ cửa hàng để đối soát hoặc hoàn tiền.',
        );
      }
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
