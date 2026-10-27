import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/clinic_model.dart';
import '../models/article_model.dart';

class ApiService {
  static const String _baseUrl = "https://my-json-server.typicode.com/hutech-cmp177/petcare-api";

  // Lấy danh sách trạm thú y & phòng khám
  Future<List<Clinic>> fetchClinics({double userLat = 10.801, double userLng = 106.711}) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/clinics'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Clinic.fromJson(json)).toList();
      }
    } catch (_) {
      // Fallback: Khi API ngoài không phản hồi hoặc offline, nạp bộ dữ liệu mock chuẩn để app luôn hoạt động
    }

    return _getFallbackClinics(userLat, userLng);
  }

  // Lấy danh sách bài viết cẩm nang chăm sóc thú cưng
  Future<List<Article>> fetchArticles({String? category}) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/articles'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Article.fromJson(json)).toList();
      }
    } catch (_) {
      // Fallback mock
    }

    return _getFallbackArticles();
  }

  // Mô phỏng tạo thanh toán
  Future<bool> createPaymentIntent(String orderId, double amount) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return true;
  }

  // Dữ liệu mẫu chuẩn cứu hộ & phòng khám thú y
  List<Clinic> _getFallbackClinics(double userLat, double userLng) {
    return [
      Clinic(
        id: "clinic_01",
        name: "Bệnh Viện Thú Y PetCare Sài Gòn",
        address: "124 Nguyễn Đình Chiểu, Phường 6, Quận 3, TP.HCM",
        latitude: 10.7825,
        longitude: 106.6912,
        phone: "02838244766",
        rating: 4.9,
        isOpen247: true,
        openHours: "24/7 (Cấp cứu ngày đêm)",
        services: ["Cấp cứu 24/7", "Phẫu thuật", "Tiêm phòng", "Spa & Khách sạn"],
        distanceKm: 1.8,
      ),
      Clinic(
        id: "clinic_02",
        name: "Phòng Khám Thú Y HUTECH AniVet",
        address: "475A Điện Biên Phủ, Phường 25, Bình Thạnh, TP.HCM",
        latitude: 10.8015,
        longitude: 106.7118,
        phone: "0909123456",
        rating: 4.8,
        isOpen247: false,
        openHours: "08:00 - 21:00",
        services: ["Khám chữa bệnh", "X-Quang & Siêu âm", "Tẩy giun & Triệt sản"],
        distanceKm: 0.5,
      ),
      Clinic(
        id: "clinic_03",
        name: "Hệ Thống Bệnh Viện Thú Y 2Vet",
        address: "348 Phan Xích Long, Phường 2, Phú Nhuận, TP.HCM",
        latitude: 10.7964,
        longitude: 106.6891,
        phone: "0986998126",
        rating: 4.7,
        isOpen247: true,
        openHours: "24/7",
        services: ["Nội trú thú cưng", "Chăm sóc nha khoa", "Cắt tỉa lông tạo kiểu"],
        distanceKm: 2.7,
      ),
      Clinic(
        id: "clinic_04",
        name: "Phòng Khám Thú Y & Pet Spa Thảo Điền",
        address: "65 Xuân Thủy, Phường Thảo Điền, TP. Thủ Đức, TP.HCM",
        latitude: 10.8062,
        longitude: 106.7324,
        phone: "0934112233",
        rating: 4.9,
        isOpen247: false,
        openHours: "08:30 - 20:30",
        services: ["Tắm Onsen thú cưng", "Grooming chuyên sâu", "Thức ăn nhập khẩu"],
        distanceKm: 3.4,
      ),
    ];
  }

  // Dữ liệu mẫu cẩm nang thú y
  List<Article> _getFallbackArticles() {
    return [
      Article(
        id: "art_01",
        title: "Lịch Tiêm Chủng Chuẩn Y Khoa Cho Chó Con Từ 6 Tuần Tuổi",
        category: "Tiêm phòng",
        author: "ThS. BS Thú Y Đỗ Minh",
        publishedAt: "15/10/2026",
        thumbnailUrl: "https://images.unsplash.com/photo-1548767797-d8c844163c4c?auto=format&fit=crop&w=600&q=80",
        summary: "Hướng dẫn chi tiết phác đồ tiêm vaccine 5 bệnh, 7 bệnh và vaccine phòng dại bắt buộc.",
        content: "Chó con cần được tiêm mũi đầu tiên lúc 6-8 tuần tuổi với vaccine 5 bệnh (Care, Parvo, Viêm gan truyền nhiễm, Ho cũi chó, Cúm). Mũi thứ hai lúc 9-11 tuần tuổi với vaccine 7 bệnh...",
        readTimeMinutes: 4,
      ),
      Article(
        id: "art_02",
        title: "Dấu Hiệu Nhận Biết Sớm Bệnh Giảm Bạch Cầu (FPV) Ở Mèo",
        category: "Bệnh lý",
        author: "BS. Thú Y Trần Lan",
        publishedAt: "12/10/2026",
        thumbnailUrl: "https://images.unsplash.com/photo-1573865526739-10659fec78a5?auto=format&fit=crop&w=600&q=80",
        summary: "Nhận biết sớm triệu chứng sốt cao, bỏ ăn, nôn bọt vàng để kịp thời cứu chữa cho mèo cưng.",
        content: "FPV là căn bệnh cực kỳ nguy hiểm ở mèo. Các biểu hiện bao gồm ủ rũ, sốt cao đột ngột, bỏ ăn hoàn toàn, nôn mửa dịch màu vàng hoặc bọt trắng, tiêu chảy ra máu...",
        readTimeMinutes: 6,
      ),
      Article(
        id: "art_03",
        title: "Chế Độ Dinh Dưỡng Khoa Học Giúp Lông Mượt Và Ngăn Ngừa Búi Lông",
        category: "Dinh dưỡng",
        author: "Chuyên gia Dinh dưỡng Thú Cưng",
        publishedAt: "10/10/2026",
        thumbnailUrl: "https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=600&q=80",
        summary: "Bổ sung Omega-3, men vi sinh và chất xơ hòa tan giúp hệ tiêu hóa khỏe mạnh và bộ lông bóng mượt.",
        content: "Dầu cá hồi chứa hàm lượng cao EPA và DHA giúp nuôi dưỡng nang lông từ sâu bên trong, hạn chế rụng lông theo mùa và cải thiện rõ rệt tình trạng viêm da dị ứng...",
        readTimeMinutes: 5,
      ),
    ];
  }
}
