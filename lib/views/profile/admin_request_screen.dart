import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/admin_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_request_service.dart';
import '../../services/app_error.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_screen.dart';

class AdminRequestScreen extends StatefulWidget {
  const AdminRequestScreen({super.key, this.service});
  final AdminRequestService? service;

  @override
  State<AdminRequestScreen> createState() => _AdminRequestScreenState();
}

class _AdminRequestScreenState extends State<AdminRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late final _service = widget.service ?? AdminRequestService();
  late Stream<AdminRequest?> _stream;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _stream = _service.watchMine();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _service.submit(_reason.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi yêu cầu. Vui lòng chờ quản trị viên duyệt.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAdmin() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.refreshPermissions();
    if (!mounted) return;
    if (!ok || !auth.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.error ?? 'Quyền đã thay đổi. Vui lòng tải lại yêu cầu.',
          ),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminScreen()),
    );
  }

  Widget _status(AdminRequest request) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AdminRequest.statusLabel(request.status),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (request.updatedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Cập nhật: ${DateFormat('dd/MM/yyyy HH:mm').format(request.updatedAt!)}',
              style: const TextStyle(color: AppTheme.textLight),
            ),
          ],
          const SizedBox(height: 12),
          Text('Lý do đã gửi: ${request.reason}'),
          if (request.reviewNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Phản hồi từ quản trị viên: ${request.reviewNote}'),
          ],
          if (request.status == AdminRequest.pending) ...[
            const SizedBox(height: 12),
            const Text(
              'Bạn sẽ nhận kết quả tại đây khi quản trị viên xử lý yêu cầu.',
            ),
          ],
          if (request.status == AdminRequest.approved) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openAdmin,
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Mở Trung tâm quản trị'),
            ),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yêu cầu quyền quản trị')),
    body: StreamBuilder<AdminRequest?>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorMessage(snapshot.error!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _stream = _service.watchMine()),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final request = snapshot.data;
        final canSubmit = request == null || request.canSubmit;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 52,
                  color: AppTheme.secondary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bạn muốn cùng quản lý PawPals?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cho quản trị viên biết lý do bạn cần quyền quản lý sản phẩm, đơn hàng, phòng khám và bài viết. Yêu cầu chỉ có hiệu lực sau khi được duyệt.',
                ),
                const SizedBox(height: 20),
                if (request != null) _status(request),
                if (canSubmit) ...[
                  const SizedBox(height: 12),
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _reason,
                          enabled: !_busy,
                          minLines: 3,
                          maxLines: 6,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            labelText: 'Lý do yêu cầu',
                            hintText: 'Mô tả công việc bạn cần thực hiện…',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) => (value?.trim().length ?? 0) < 10
                              ? 'Vui lòng nhập lý do ít nhất 10 ký tự.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: const Icon(Icons.send_outlined),
                          label: Text(
                            _busy
                                ? 'Đang gửi…'
                                : request == null
                                ? 'Gửi yêu cầu'
                                : 'Gửi lại yêu cầu',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}
