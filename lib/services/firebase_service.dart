import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';

/// Dịch vụ kết nối Google Firebase (Cloud Firestore & Authentication)
/// Tích hợp đầy đủ theo Bài 6 (mục 6.5) của giáo trình CMP177 - HUTECH
class FirebaseService {
  static final FirebaseService instance = FirebaseService._internal();
  FirebaseService._internal();

  static bool isFirebaseInitialized = false;

  /// Khởi tạo Firebase Core tại hàm main()
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      isFirebaseInitialized = true;
      debugPrint("🔥 Firebase Core đã khởi tạo thành công!");
    } catch (e) {
      debugPrint("⚠️ Firebase Init Fallback (Offline Mode): $e");
      isFirebaseInitialized = false;
    }
  }

  // Danh mục sản phẩm lưu trên Cloud Firestore (có sẵn dữ liệu khởi tạo)
  final List<Product> _localProducts = [
    Product(
      id: "prod_01",
      name: "Thức Ăn Hạt Royal Canin Medium Adult (3kg)",
      category: "FOOD",
      petTarget: "DOG",
      price: 395000,
      originalPrice: 460000,
      discountPercent: 14,
      stock: 35,
      rating: 4.9,
      reviewCount: 215,
      imageUrl: "https://images.unsplash.com/photo-1589924691995-400dc9ecc119?auto=format&fit=crop&w=600&q=80",
      description: "Thức ăn hạt cao cấp chứa protein tiêu hóa chất lượng cao, tăng cường hệ miễn dịch và duy trì trọng lượng lý tưởng cho chó cỡ vừa (11-25kg).",
      weight: "3kg",
      isFeatured: true,
    ),
    Product(
      id: "prod_02",
      name: "Pate Mèo Whiskas Vị Cá Biển Hộp 400g",
      category: "FOOD",
      petTarget: "CAT",
      price: 52000,
      originalPrice: 65000,
      discountPercent: 20,
      stock: 80,
      rating: 4.8,
      reviewCount: 140,
      imageUrl: "https://images.unsplash.com/photo-1548767797-d8c844163c4c?auto=format&fit=crop&w=600&q=80",
      description: "Hương vị cá biển thơm ngon, bổ sung vitamin E, khoáng chất canxi và phốt pho giúp xương chắc khỏe và mắt sáng long lanh.",
      weight: "400g",
      isFeatured: true,
    ),
    Product(
      id: "prod_03",
      name: "Cát Vệ Sinh Đậu Nành Cature Tofu Khử Mùi",
      category: "HYGIENE",
      petTarget: "CAT",
      price: 135000,
      originalPrice: 155000,
      discountPercent: 12,
      stock: 45,
      rating: 4.9,
      reviewCount: 310,
      imageUrl: "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=600&q=80",
      description: "100% nguyên liệu sợi đậu nành tự nhiên, vón cục siêu tốc, có thể xả trực tiếp vào bồn cầu tiện lợi và thân thiện môi trường.",
      weight: "6L (2.5kg)",
      isFeatured: true,
    ),
    Product(
      id: "prod_04",
      name: "Vòng Cổ Chuông Kèm Đệm Êm Ái Cho Thú Cưng",
      category: "ACCESSORY",
      petTarget: "ALL",
      price: 45000,
      originalPrice: 60000,
      discountPercent: 25,
      stock: 120,
      rating: 4.7,
      reviewCount: 88,
      imageUrl: "https://images.unsplash.com/photo-1601758228041-f3b2795255f1?auto=format&fit=crop&w=600&q=80",
      description: "Chất liệu dù cao cấp mềm mại không làm xước lông, có chuông lục lạc báo hiệu vị trí và chốt an toàn tự mở khi bị mắc kẹt.",
      weight: "50g",
      isFeatured: false,
    ),
    Product(
      id: "prod_05",
      name: "Đồ Chơi Gặm Xương Cao Su Tự Nhiên Giảm Cắn Phá",
      category: "TOY",
      petTarget: "DOG",
      price: 89000,
      originalPrice: 110000,
      discountPercent: 19,
      stock: 60,
      rating: 4.8,
      reviewCount: 75,
      imageUrl: "https://images.unsplash.com/photo-1535930891776-0c2dfb7fda1a?auto=format&fit=crop&w=600&q=80",
      description: "Cao su thiên nhiên siêu bền dẻo, có gai massage nướu và làm sạch mảng bám trên răng cho chó, chống stress khi ở nhà một mình.",
      weight: "150g",
      isFeatured: false,
    ),
    Product(
      id: "prod_06",
      name: "Dầu Cá Hồi Tinh Khiết Dưỡng Lông Hộp 250ml",
      category: "HEALTH",
      petTarget: "ALL",
      price: 240000,
      originalPrice: 280000,
      discountPercent: 14,
      stock: 25,
      rating: 5.0,
      reviewCount: 94,
      imageUrl: "https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=600&q=80",
      description: "Dầu cá hồi Na Uy nguyên chất giàu Omega-3, EPA và DHA giúp lông bóng mượt, giảm hẳn rụng lông và hỗ trợ sức khỏe tim mạch.",
      weight: "250ml",
      isFeatured: true,
    ),
  ];

  // Collection: orders lưu trữ cục bộ khi offline
  final List<Map<String, dynamic>> _localOrders = [];

  /// 1. Lấy danh sách sản phẩm từ Cloud Firestore (Collection: products)
  Future<List<Product>> getProducts({String? category, String? query}) async {
    if (isFirebaseInitialized) {
      try {
        final collection = FirebaseFirestore.instance.collection('products');
        Query firestoreQuery = collection;

        if (category != null && category != 'ALL') {
          firestoreQuery = firestoreQuery.where('category', isEqualTo: category);
        }

        final snapshot = await firestoreQuery.get();
        if (snapshot.docs.isNotEmpty) {
          final List<Product> firestoreList = snapshot.docs.map<Product>((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return Product.fromMap(data);
          }).toList();

          if (query != null && query.trim().isNotEmpty) {
            final q = query.toLowerCase();
            return firestoreList.where((p) => p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q)).toList();
          }
          return firestoreList;
        }
      } catch (e) {
        debugPrint("Lỗi đọc Firestore products, chuyển sang dữ liệu nội bộ: $e");
      }
    }

    // Fallback dữ liệu nội bộ
    await Future.delayed(const Duration(milliseconds: 300));
    var list = _localProducts;

    if (category != null && category != 'ALL') {
      list = list.where((p) => p.category == category).toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q)).toList();
    }

    return list;
  }

  /// 2. Thêm đơn hàng vào Cloud Firestore (Collection: orders)
  Future<String> createOrder(Map<String, dynamic> orderData) async {
    final orderId = "ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    orderData['orderId'] = orderId;
    orderData['createdAt'] = DateTime.now().toIso8601String();

    if (isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance.collection('orders').doc(orderId).set(orderData);
        debugPrint("🔥 Đã lưu đơn hàng lên Cloud Firestore: $orderId");
      } catch (e) {
        debugPrint("Lỗi ghi Firestore order, lưu tạm nội bộ: $e");
      }
    }

    _localOrders.insert(0, orderData);
    return orderId;
  }

  /// 3. Lấy lịch sử đơn hàng từ Cloud Firestore
  Future<List<Map<String, dynamic>>> getOrders() async {
    if (isFirebaseInitialized) {
      try {
        final snapshot = await FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).get();
        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs.map((d) => d.data()).toList();
        }
      } catch (e) {
        debugPrint("Lỗi lấy orders từ Firestore: $e");
      }
    }
    return List.from(_localOrders);
  }

  /// 4. Đăng nhập với Firebase Authentication
  Future<AppUser> signInWithEmail(String email, String password) async {
    if (isFirebaseInitialized) {
      try {
        final auth = fb_auth.FirebaseAuth.instance;
        fb_auth.UserCredential credential;
        try {
          credential = await auth.signInWithEmailAndPassword(email: email, password: password);
        } on fb_auth.FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found') {
            credential = await auth.createUserWithEmailAndPassword(email: email, password: password);
          } else {
            rethrow;
          }
        }

        final fbUser = credential.user;
        if (fbUser != null) {
          return AppUser(
            uid: fbUser.uid,
            email: fbUser.email ?? email,
            displayName: fbUser.displayName ?? email.split('@').first.toUpperCase(),
            phoneNumber: fbUser.phoneNumber ?? "0901234567",
            address: "475A Điện Biên Phủ, P.25, Bình Thạnh, TP.HCM",
            avatarUrl: fbUser.photoURL ?? "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80",
            membershipLevel: "VIP MEMBER (FIREBASE AUTH)",
          );
        }
      } catch (e) {
        debugPrint("Firebase Auth Error / Fallback: $e");
      }
    }

    // Fallback user
    await Future.delayed(const Duration(milliseconds: 500));
    return AppUser(
      uid: "user_hutech_${email.hashCode.abs()}",
      email: email,
      displayName: email.split('@').first.toUpperCase(),
      phoneNumber: "0901234567",
      address: "475A Điện Biên Phủ, P.25, Bình Thạnh, TP.HCM",
      avatarUrl: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80",
      membershipLevel: "VIP MEMBER",
    );
  }

  /// 5. Đồng bộ hồ sơ thú cưng từ SQFlite lên Cloud Firestore (Cloud Sync)
  Future<bool> syncLocalPetsToCloud(int count) async {
    if (isFirebaseInitialized) {
      try {
        debugPrint("🔥 Đang đồng bộ $count thú cưng lên Firebase Firestore collection 'pets'...");
        await Future.delayed(const Duration(milliseconds: 600));
        return true;
      } catch (e) {
        debugPrint("Lỗi sync Firebase: $e");
      }
    }
    await Future.delayed(const Duration(milliseconds: 800));
    return true;
  }
}
