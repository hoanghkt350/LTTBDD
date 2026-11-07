import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../services/app_error.dart';
import '../../services/order_workflow.dart';
import '../../theme/app_theme.dart';
import 'entity_editor.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, this.service});
  final AdminService? service;

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isAdmin) {
      return const AdminAccessDenied();
    }
    return _AdminWorkspace(service: service ?? AdminService());
  }
}

class AdminAccessDenied extends StatelessWidget {
  const AdminAccessDenied({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản trị')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: AppTheme.secondary),
            SizedBox(height: 16),
            Text('Bạn không có quyền quản trị.', textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class _AdminWorkspace extends StatefulWidget {
  const _AdminWorkspace({required this.service});
  final AdminService service;
  @override
  State<_AdminWorkspace> createState() => _AdminWorkspaceState();
}

class _AdminWorkspaceState extends State<_AdminWorkspace> {
  static const _sections = [
    ('products', 'Sản phẩm', Icons.inventory_2_outlined),
    ('orders', 'Đơn hàng', Icons.receipt_long_outlined),
    ('clinics', 'Phòng khám', Icons.local_hospital_outlined),
    ('articles', 'Bài viết', Icons.article_outlined),
    ('users', 'Tài khoản', Icons.people_outline),
  ];
  int _section = 0, _limit = 100;
  bool _busy = false;
  String _search = '', _orderFilter = 'Tất cả';
  final _searchController = TextEditingController();
  late Stream<List<Map<String, dynamic>>> _stream;
  final _money = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );
  String get _collection => _sections[_section].$1;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _stream = widget.service.watch(_collection, limit: _limit);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _select(int index) => setState(() {
    _section = index;
    _limit = 100;
    _search = '';
    _orderFilter = 'Tất cả';
    _searchController.clear();
    _reload();
  });

  Future<void> _perform(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _edit([Map<String, dynamic>? record]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminEntityEditor(
          collection: _collection,
          record: record,
          service: widget.service,
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final collection = _collection;
    if (!await _confirm(
      'Xóa nội dung?',
      'Nội dung này sẽ không còn hiển thị trong ứng dụng.',
    )) {
      return;
    }
    await _perform(
      () => widget.service.deleteContent(collection, record['_id'] as String),
      'Đã xóa nội dung.',
    );
  }

  Future<void> _changeStatus(Map<String, dynamic> order, String status) async {
    if (!await _confirm(
      'Cập nhật đơn hàng?',
      status == OrderWorkflow.cancelled
          ? 'Hủy đơn và hoàn trả tồn kho cho tất cả sản phẩm trong đơn?'
          : 'Chuyển đơn hàng sang trạng thái “$status”?',
    )) {
      return;
    }
    await _perform(
      () => widget.service.updateOrderStatus(order['_id'] as String, status),
      'Đã cập nhật đơn hàng.',
    );
  }

  Widget _order(Map<String, dynamic> order) {
    final recipient = Map<String, dynamic>.from(
      order['recipient'] as Map? ?? {},
    );
    final items = Map<String, dynamic>.from(order['items'] as Map? ?? {});
    final date = (order['createdAt'] as Timestamp?)?.toDate();
    final status = order['status'] as String? ?? '';
    return Card(
      child: ExpansionTile(
        key: ValueKey(order['_id']),
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(
          '${recipient['name'] ?? 'Khách hàng'} • ${_money.format(order['totalAmount'] ?? 0)}',
        ),
        subtitle: Text(
          '$status${date == null ? '' : ' • ${DateFormat('dd/MM/yyyy HH:mm').format(date)}'}',
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: [
          SelectableText('Mã đơn: ${order['_id']}'),
          Text('Người nhận: ${recipient['name'] ?? ''}'),
          Text('Điện thoại: ${recipient['phone'] ?? ''}'),
          Text('Địa chỉ: ${recipient['address'] ?? ''}'),
          const Divider(),
          for (final item in items.values)
            Text(
              '${item['quantity']} × ${item['name']} • ${_money.format(item['price'] ?? 0)}',
            ),
          const SizedBox(height: 8),
          Text(
            'Giảm giá: ${_money.format(order['discountAmount'] ?? 0)} • Vận chuyển: ${_money.format(order['shippingFee'] ?? 0)}',
          ),
          const Text('Thanh toán khi nhận hàng (COD)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final next in OrderWorkflow.nextStatuses(status))
                OutlinedButton(
                  onPressed: _busy ? null : () => _changeStatus(order, next),
                  child: Text(switch (next) {
                    OrderWorkflow.shipping => 'Xác nhận giao hàng',
                    OrderWorkflow.completed => 'Đánh dấu hoàn thành',
                    _ => 'Hủy đơn và hoàn kho',
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _record(Map<String, dynamic> record) {
    if (_collection == 'orders') return _order(record);
    if (_collection == 'users') {
      return Card(
        child: ExpansionTile(
          leading: const Icon(Icons.person_outline),
          title: Text(record['displayName'] as String? ?? 'Tài khoản'),
          subtitle: Text(record['email'] as String? ?? ''),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text('Điện thoại: ${record['phoneNumber'] ?? 'Chưa có'}'),
            Text('Địa chỉ: ${record['address'] ?? 'Chưa có'}'),
          ],
        ),
      );
    }
    final product = _collection == 'products';
    final active = record['isActive'] != false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (record['name'] ?? record['title'] ?? '') as String,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              product
                  ? '${_money.format(record['price'] ?? 0)} • Tồn kho: ${record['stock'] ?? 0}\n${active ? 'Đang bán' : 'Đã ngừng bán'}'
                  : (_collection == 'clinics'
                        ? '${record['address'] ?? ''}\n${record['phone'] ?? ''}'
                        : '${record['category'] ?? ''} • ${record['author'] ?? ''}'),
              style: const TextStyle(color: AppTheme.textLight),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : () => _edit(record),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Chỉnh sửa'),
                ),
                if (product)
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _perform(
                            () => widget.service.setProductActive(
                              record['_id'] as String,
                              !active,
                            ),
                            active
                                ? 'Đã ngừng bán sản phẩm.'
                                : 'Đã mở bán sản phẩm.',
                          ),
                    icon: Icon(
                      active
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 18,
                    ),
                    label: Text(active ? 'Ngừng bán' : 'Mở bán'),
                  )
                else
                  TextButton.icon(
                    onPressed: _busy ? null : () => _delete(record),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Xóa'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Trung tâm quản trị'),
      actions: [
        IconButton(
          tooltip: 'Tải lại danh sách',
          onPressed: _busy ? null : () => setState(_reload),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton:
        ['products', 'clinics', 'articles'].contains(_collection)
        ? FloatingActionButton.extended(
            onPressed: _busy ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Thêm mới'),
          )
        : null,
    body: Column(
      children: [
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemCount: _sections.length,
            itemBuilder: (_, index) => ChoiceChip(
              selected: _section == index,
              avatar: Icon(_sections[index].$3, size: 18),
              label: Text(_sections[index].$2),
              onSelected: _busy ? null : (_) => _select(index),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Tìm trong danh sách đã tải',
            ),
            onChanged: (value) =>
                setState(() => _search = value.trim().toLowerCase()),
          ),
        ),
        if (_collection == 'orders')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              key: ValueKey('order-filter-$_section'),
              initialValue: _orderFilter,
              decoration: const InputDecoration(
                labelText: 'Trạng thái đơn hàng',
              ),
              items:
                  [
                        'Tất cả',
                        OrderWorkflow.pending,
                        OrderWorkflow.shipping,
                        OrderWorkflow.completed,
                        OrderWorkflow.cancelled,
                      ]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _orderFilter = value!),
            ),
          ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            key: ValueKey('$_collection-$_limit'),
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(errorMessage(snapshot.error!)),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final loaded = snapshot.data!;
              final records = loaded
                  .where(
                    (record) =>
                        (_collection != 'orders' ||
                            _orderFilter == 'Tất cả' ||
                            record['status'] == _orderFilter) &&
                        (_search.isEmpty ||
                            record.values
                                .join(' ')
                                .toLowerCase()
                                .contains(_search)),
                  )
                  .toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  Text(
                    '${records.length} kết quả • Đã tải ${loaded.length} mục',
                    style: const TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Chưa có dữ liệu phù hợp.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...records.map(_record),
                  if (loaded.length >= _limit && _limit < 5000)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _limit += 100;
                              _reload();
                            }),
                      child: const Text('Tải thêm'),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
