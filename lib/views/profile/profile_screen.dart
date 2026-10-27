import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pet_provider.dart';
import '../../services/firebase_mock_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showOrderHistoryDialog(BuildContext context) async {
    final orders = await FirebaseService.instance.getOrders();

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lịch Sử Đơn Hàng (Firestore)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
              const Divider(),
              Expanded(
                child: orders.isEmpty
                    ? const Center(child: Text('Bạn chưa có đơn đặt hàng nào.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final o = orders[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF4ECDC4),
                                child: Icon(Icons.shopping_bag, color: Colors.white),
                              ),
                              title: Text('Đơn hàng: ${o['orderId']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('Trạng thái: ${o['status']}\nNgày: ${o['createdAt'].toString().substring(0, 10)}'),
                              trailing: Text('${o['totalAmount']} đ', style: const TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pet = context.watch<PetProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ Sơ Của Tôi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar & Name Card (Bài 4 mục 4.1.1.2 CircleAvatar)
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: const Color(0xFFFF6B6B).withOpacity(0.15),
                    backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                    child: user?.avatarUrl == null
                        ? const Icon(Icons.person, size: 46, color: Color(0xFFFF6B6B))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ?? 'Chủ Nuôi Thú Cưng',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFBE0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user?.membershipLevel ?? 'VIP MEMBER',
                      style: const TextStyle(color: Color(0xFFD48B00), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Thông tin chi tiết Card
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.email_outlined, color: Color(0xFFFF6B6B)),
                      title: const Text('Email tài khoản', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      subtitle: Text(user?.email ?? 'student@hutech.edu.vn', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.phone_outlined, color: Color(0xFF4ECDC4)),
                      title: const Text('Số điện thoại', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      subtitle: Text(user?.phoneNumber ?? '0901234567', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined, color: Color(0xFFFFBE0B)),
                      title: const Text('Địa chỉ nhận hàng mặc định', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      subtitle: Text(user?.address ?? '475A Điện Biên Phủ, P.25, Bình Thạnh, TP.HCM', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Các chức năng tiện ích
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined, color: Colors.blueAccent),
                    title: const Text('Lịch sử đơn mua hàng (Firestore)', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showOrderHistoryDialog(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF4ECDC4)),
                    title: const Text('Sao lưu dữ liệu SQFlite lên mây', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Đang quản lý ${pet.pets.length} bé cưng'),
                    trailing: pet.isSyncing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync_rounded),
                    onTap: () async {
                      final ok = await pet.syncDataToCloud();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'Đồng bộ dữ liệu thú cưng lên Firebase thành công!' : 'Thất bại'),
                          backgroundColor: const Color(0xFF4ECDC4),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.school_outlined, color: Colors.deepPurpleAccent),
                    title: const Text('Thông tin đồ án môn học', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Lập trình trên Thiết bị di động (CMP177)'),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'PawPals App',
                        applicationVersion: '1.0.0+1',
                        applicationLegalese: 'Đồ án môn học CMP177 - HUTECH 2024\nBiên soạn: ThS. Bùi Phú Khuyên\nTích hợp: Flutter, Firebase, SQFlite, REST API',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Nút Đăng xuất
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('ĐĂNG XUẤT', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Xác nhận đăng xuất?'),
                      content: const Text('Bạn có chắc chắn muốn đăng xuất tài khoản?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('HỦY')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await auth.logout();
                            if (!context.mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                              (route) => false,
                            );
                          },
                          child: const Text('ĐĂNG XUẤT'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
