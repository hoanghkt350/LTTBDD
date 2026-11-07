import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/pet_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/clinic_provider.dart';
import '../../services/app_error.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pawpals_logo.dart';
import 'orders_screen.dart';
import '../admin/admin_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  Future<void> _edit(BuildContext context) async {
    await showDialog(context: context, builder: (_) => const _ProfileDialog());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pets = context.watch<PetProvider>();
    final user = auth.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.mint,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 42,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textLight),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Cùng bé lớn lên mỗi ngày',
                  style: TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (auth.error != null)
            Text(auth.error!, style: const TextStyle(color: Colors.orange)),
          const Card(
            child: ListTile(
              leading: Icon(Icons.verified_user_outlined),
              title: Text('Email đã xác nhận'),
              subtitle: Text('Tài khoản đã xác minh quyền sở hữu email.'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                auth.isAdmin
                    ? Icons.admin_panel_settings_outlined
                    : Icons.person_outline,
              ),
              title: Text(auth.isAdmin ? 'Quản trị viên' : 'Người dùng'),
              trailing: IconButton(
                tooltip: 'Cập nhật quyền tài khoản',
                icon: const Icon(Icons.refresh),
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        final ok = await auth.refreshPermissions();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Đã cập nhật quyền tài khoản.'
                                    : auth.error ?? 'Chưa cập nhật được quyền.',
                              ),
                            ),
                          );
                        }
                      },
              ),
            ),
          ),
          if (auth.isAdmin)
            Card(
              child: ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('Trung tâm quản trị'),
                subtitle: const Text(
                  'Sản phẩm, đơn hàng, nội dung và tài khoản',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  );
                  if (context.mounted) {
                    await Future.wait([
                      context.read<ShopProvider>().fetchProducts(),
                      context.read<ClinicProvider>().loadClinicsAndArticles(),
                    ]);
                  }
                },
              ),
            ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Chỉnh sửa thông tin'),
                  subtitle: Text(
                    '${user.phoneNumber ?? 'Chưa có số điện thoại'}\n${user.address ?? 'Chưa có địa chỉ'}',
                  ),
                  onTap: () => _edit(context),
                ),
                ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: const Text('Đơn hàng của tôi'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrdersScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_sync),
                  title: const Text('Đồng bộ và khôi phục dữ liệu'),
                  subtitle: Text(
                    pets.isSyncing
                        ? 'Đang đồng bộ…'
                        : '${pets.pendingCount} thay đổi đang chờ',
                  ),
                  onTap: pets.isSyncing
                      ? null
                      : () async {
                          final ok = await pets.syncDataToCloud();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Đồng bộ thành công.'
                                      : pets.syncError ?? 'Chưa thể đồng bộ.',
                                ),
                              ),
                            );
                          }
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Gửi email đổi mật khẩu'),
                  onTap: auth.isLoading
                      ? null
                      : () async {
                          final ok = await auth.resetPassword(user.email);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Đã gửi hướng dẫn đổi mật khẩu vào email.'
                                      : auth.error ?? 'Không gửi được.',
                                ),
                              ),
                            );
                          }
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Về PawPals'),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'PawPals',
                    applicationIcon: const PawPalsLogo(size: 56),
                    applicationVersion: '1.0.0',
                    applicationLegalese: 'Ứng dụng quản lý thú cưng, sổ sức khỏe, nhắc lịch và mua sắm.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
            onPressed: pets.isSyncing || pets.isLoading
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Đăng xuất?'),
                        content: Text(
                          pets.pendingCount > 0
                              ? 'Bạn còn ${pets.pendingCount} thay đổi chưa đồng bộ. Dữ liệu vẫn được giữ trên máy cho tài khoản này. Nên đồng bộ trước nếu bạn sắp đổi thiết bị.'
                              : 'Thông báo của tài khoản này sẽ tạm dừng trên thiết bị.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Quay lại'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Đăng xuất'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    try {
                      await NotificationService.instance.clear().catchError(
                        (Object _) {},
                      );
                      await auth.logout();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(errorMessage(e))),
                        );
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog();
  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _phone, _address;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _name = TextEditingController(text: user.displayName);
    _phone = TextEditingController(text: user.phoneNumber);
    _address = TextEditingController(text: user.address);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      auth.user!.copyWith(
        displayName: _name.text.trim(),
        phoneNumber: _phone.text.trim(),
        address: _address.text.trim(),
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = auth.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Thông tin cá nhân'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Họ tên'),
              validator: (v) =>
                  (v?.trim().isNotEmpty ?? false) ? null : 'Nhập họ tên',
            ),
            TextFormField(
              controller: _phone,
              maxLength: 13,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Điện thoại'),
              validator: (v) =>
                  v == null ||
                      v.isEmpty ||
                      RegExp(r'^\+?[0-9]{9,12}$').hasMatch(v.trim())
                  ? null
                  : 'Số điện thoại không hợp lệ',
            ),
            TextFormField(
              controller: _address,
              maxLength: 300,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Địa chỉ'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      ElevatedButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
      ),
    ],
  );
}
