import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../services/app_error.dart';
import 'admin_screen.dart';

class AdminEntityEditor extends StatefulWidget {
  const AdminEntityEditor({
    super.key,
    required this.collection,
    required this.service,
    this.record,
  });
  final String collection;
  final AdminService service;
  final Map<String, dynamic>? record;
  @override
  State<AdminEntityEditor> createState() => _AdminEntityEditorState();
}

class _AdminEntityEditorState extends State<AdminEntityEditor> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _choices = <String, String>{};
  final _switches = <String, bool>{};
  bool _saving = false;
  String? _error;
  bool get _product => widget.collection == 'products';
  bool get _clinic => widget.collection == 'clinics';
  TextEditingController _controller(String name, [String fallback = '']) =>
      _controllers.putIfAbsent(
        name,
        () => TextEditingController(
          text: widget.record?[name]?.toString() ?? fallback,
        ),
      );
  String _text(String name) => _controller(name).text.trim();
  double? _number(String name) =>
      double.tryParse(_text(name).replaceAll(',', '.'));

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String name,
    String label, {
    int max = 120,
    int lines = 1,
    bool required = true,
    bool number = false,
    String fallback = '',
    String? hint,
    String? Function(String)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _controller(name, fallback),
      enabled: !_saving,
      maxLength: max,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 3,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : (lines > 1 ? TextInputType.multiline : TextInputType.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) return 'Vui lòng nhập $label';
        if (text.length > max) return 'Tối đa $max ký tự';
        if (text.isEmpty && !required) return null;
        return validate?.call(text);
      },
    ),
  );

  String? _bounded(
    String text,
    double min,
    double max, {
    bool integer = false,
  }) {
    final number = double.tryParse(text.replaceAll(',', '.'));
    if (number == null ||
        !number.isFinite ||
        number < min ||
        number > max ||
        (integer && int.tryParse(text) == null)) {
      return integer
          ? 'Nhập số nguyên từ ${min.toInt()} đến ${max.toInt()}'
          : 'Nhập số từ $min đến $max';
    }
    return null;
  }

  String? _image(String text) {
    final uri = Uri.tryParse(text);
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            !text.contains(' ')
        ? null
        : 'Nhập liên kết ảnh HTTPS hợp lệ';
  }

  Widget _dropdown(String name, String label, Map<String, String> values) {
    final value = _choices.putIfAbsent(name, () {
      final initial = widget.record?[name] as String?;
      return values.containsKey(initial) ? initial! : values.keys.first;
    });
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: values.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: _saving
            ? null
            : (value) => setState(() => _choices[name] = value!),
      ),
    );
  }

  Widget _switch(String name, String label, {bool fallback = false}) {
    final value = _switches.putIfAbsent(
      name,
      () => widget.record?[name] as bool? ?? fallback,
    );
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: _saving
          ? null
          : (value) => setState(() => _switches[name] = value),
    );
  }

  List<Widget> _fields() {
    if (_product) {
      return [
        _field('name', 'Tên sản phẩm'),
        _dropdown('category', 'Danh mục', {
          'FOOD': 'Thức ăn',
          'ACCESSORY': 'Phụ kiện',
          'TOY': 'Đồ chơi',
          'HEALTH': 'Sức khỏe',
          'HYGIENE': 'Vệ sinh',
        }),
        _dropdown('petTarget', 'Dành cho', {
          'ALL': 'Chó và mèo',
          'DOG': 'Chó',
          'CAT': 'Mèo',
        }),
        _field(
          'price',
          'Giá bán (đ)',
          number: true,
          validate: (value) => _bounded(value, 1, 1000000000),
        ),
        _field(
          'originalPrice',
          'Giá gốc (đ)',
          required: false,
          number: true,
          hint: 'Để trống nếu không giảm giá',
          validate: (value) {
            final error = _bounded(value, 1, 1000000000);
            if (error != null) return error;
            return (_number('originalPrice') ?? 0) >= (_number('price') ?? 0)
                ? null
                : 'Giá gốc phải lớn hơn hoặc bằng giá bán';
          },
        ),
        _field(
          'stock',
          'Số lượng tồn kho',
          number: true,
          fallback: '0',
          validate: (value) => _bounded(value, 0, 1000000, integer: true),
        ),
        _field('weight', 'Quy cách / trọng lượng', max: 80, required: false),
        _field(
          'imageUrl',
          'Liên kết ảnh',
          max: 2000,
          required: false,
          hint: 'https://...',
          validate: _image,
        ),
        _field(
          'description',
          'Mô tả sản phẩm',
          max: 10000,
          lines: 4,
          required: false,
        ),
        _switch('isFeatured', 'Hiển thị trong sản phẩm nổi bật'),
        _switch('isActive', 'Đang mở bán', fallback: true),
      ];
    }
    if (_clinic) {
      return [
        _field('name', 'Tên phòng khám'),
        _field('address', 'Địa chỉ', max: 300, lines: 2),
        _field(
          'phone',
          'Số điện thoại',
          max: 13,
          validate: (value) => RegExp(r'^\+?[0-9]{9,12}$').hasMatch(value)
              ? null
              : 'Số điện thoại không hợp lệ',
        ),
        _field(
          'latitude',
          'Vĩ độ',
          number: true,
          validate: (value) => _bounded(value, -90, 90),
        ),
        _field(
          'longitude',
          'Kinh độ',
          number: true,
          validate: (value) => _bounded(value, -180, 180),
        ),
        _field('openHours', 'Giờ làm việc', fallback: '08:00 - 21:00'),
        _field(
          'services',
          'Dịch vụ',
          max: 1600,
          lines: 2,
          required: false,
          fallback: '',
          hint: 'Khám tổng quát, Tiêm phòng',
          validate: (value) =>
              value.split(',').where((s) => s.trim().isNotEmpty).length <= 20
              ? null
              : 'Tối đa 20 dịch vụ',
        ),
        _switch('isOpen24_7', 'Hoạt động 24/7'),
      ];
    }
    return [
      _field('title', 'Tiêu đề bài viết', max: 160),
      _field('category', 'Chuyên mục', max: 80),
      _field('author', 'Tác giả', max: 80),
      _field(
        'publishedAt',
        'Ngày đăng (yyyy-MM-dd)',
        max: 10,
        fallback: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        validate: (value) {
          final date = DateTime.tryParse(value);
          return date != null && DateFormat('yyyy-MM-dd').format(date) == value
              ? null
              : 'Nhập ngày hợp lệ theo yyyy-MM-dd';
        },
      ),
      _field(
        'thumbnailUrl',
        'Liên kết ảnh bìa',
        max: 2000,
        required: false,
        hint: 'https://...',
        validate: _image,
      ),
      _field('summary', 'Tóm tắt', max: 1000, lines: 3),
      _field('content', 'Nội dung', max: 50000, lines: 8),
      _field(
        'readTimeMinutes',
        'Thời gian đọc (phút)',
        number: true,
        fallback: '5',
        validate: (value) => _bounded(value, 1, 120, integer: true),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    final services = widget.record?['services'];
    if (_clinic && services is List) {
      _controllers['services'] = TextEditingController(
        text: services.join(', '),
      );
    }
  }

  Map<String, dynamic> _data() {
    if (_product) {
      final price = _number('price')!,
          original = _number('originalPrice') ?? _number('price')!;
      return {
        'name': _text('name'),
        'category': _choices['category'],
        'petTarget': _choices['petTarget'],
        'price': price,
        'originalPrice': original,
        'stock': int.parse(_text('stock')),
        'discountPercent': ((original - price) / original * 100).round(),
        'weight': _text('weight'),
        'imageUrl': _text('imageUrl'),
        'description': _text('description'),
        'isFeatured': _switches['isFeatured'],
        'isActive': _switches['isActive'],
        if (widget.record == null) ...{'rating': 0, 'reviewCount': 0},
      };
    }
    if (_clinic) {
      return {
        'name': _text('name'),
        'address': _text('address'),
        'phone': _text('phone'),
        'latitude': _number('latitude'),
        'longitude': _number('longitude'),
        'openHours': _text('openHours'),
        'services': _text('services')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList(),
        'isOpen24_7': _switches['isOpen24_7'],
        if (widget.record == null) ...{'rating': 0, 'distanceKm': 0},
      };
    }
    return {
      for (final key in [
        'title',
        'category',
        'author',
        'publishedAt',
        'thumbnailUrl',
        'summary',
        'content',
      ])
        key: _text(key),
      'readTimeMinutes': int.parse(_text('readTimeMinutes')),
    };
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.save(
        widget.collection,
        widget.record?['_id'] as String?,
        _data(),
        original: widget.record,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isAdmin) {
      return const AdminAccessDenied();
    }
    final name = _product
        ? 'sản phẩm'
        : _clinic
        ? 'phòng khám'
        : 'bài viết';
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.record == null ? 'Thêm' : 'Sửa'} $name'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._fields(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Đang lưu…' : 'Lưu thay đổi'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
