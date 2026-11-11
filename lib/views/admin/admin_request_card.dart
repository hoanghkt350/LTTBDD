import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/admin_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class AdminRequestCard extends StatelessWidget {
  const AdminRequestCard({
    super.key,
    required this.request,
    required this.busy,
    required this.onReview,
  });

  final AdminRequest request;
  final bool busy;
  final Future<void> Function(String decision, String note) onReview;

  Future<void> _review(BuildContext context, String decision) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewDialog(request: request, decision: decision),
    );
    if (note != null && context.mounted) await onReview(decision, note);
  }

  @override
  Widget build(BuildContext context) {
    final self = context.read<AuthProvider>().user?.uid == request.uid;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(request.email),
            const SizedBox(height: 8),
            Text(
              AdminRequest.statusLabel(request.status),
              style: const TextStyle(
                color: AppTheme.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (request.updatedAt != null)
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(request.updatedAt!),
                style: const TextStyle(color: AppTheme.textLight, fontSize: 12),
              ),
            const SizedBox(height: 12),
            Text(request.reason),
            if (request.reviewNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Phản hồi: ${request.reviewNote}'),
            ],
            if (!self && request.status == AdminRequest.pending) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _review(context, AdminRequest.approved),
                    icon: const Icon(Icons.check),
                    label: const Text('Duyệt cấp quyền'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _review(context, AdminRequest.rejected),
                    child: const Text('Từ chối'),
                  ),
                ],
              ),
            ],
            if (!self && request.status == AdminRequest.approved) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _review(context, AdminRequest.revoked),
                icon: const Icon(Icons.remove_moderator_outlined),
                label: const Text('Thu hồi quyền'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.request, required this.decision});
  final AdminRequest request;
  final String decision;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(switch (widget.decision) {
      AdminRequest.approved => 'Cấp quyền quản trị?',
      AdminRequest.rejected => 'Từ chối yêu cầu?',
      _ => 'Thu hồi quyền quản trị?',
    }),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.request.email,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(switch (widget.decision) {
              AdminRequest.approved => 'Tài khoản này sẽ được quản lý sản phẩm, đơn hàng, phòng khám, bài viết và duyệt yêu cầu cấp quyền.',
              AdminRequest.rejected =>
                'Người gửi sẽ thấy kết quả từ chối và có thể gửi lại yêu cầu.',
              _ => 'Quyền quản trị được cấp qua yêu cầu này sẽ bị thu hồi.',
            }),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Phản hồi (không bắt buộc)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Quay lại'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _note.text.trim()),
        child: const Text('Xác nhận'),
      ),
    ],
  );
}
