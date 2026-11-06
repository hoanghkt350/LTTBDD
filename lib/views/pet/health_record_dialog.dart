import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/health_record_model.dart';
import '../../providers/pet_provider.dart';
import '../../services/app_error.dart';

class HealthRecordDialog extends StatefulWidget {
  final int petId;
  final HealthRecord? record;
  const HealthRecordDialog({super.key, required this.petId, this.record});
  @override
  State<HealthRecordDialog> createState() => _HealthRecordDialogState();
}

class _HealthRecordDialogState extends State<HealthRecordDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _vet, _clinic, _notes, _cost;
  late String _type;
  late DateTime _date;
  DateTime? _next;
  String? _error;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _title = TextEditingController(text: r?.title);
    _vet = TextEditingController(text: r?.veterinarian);
    _clinic = TextEditingController(text: r?.clinicName);
    _notes = TextEditingController(text: r?.notes);
    _cost = TextEditingController(text: r?.cost.toString() ?? '0');
    _type = r?.recordType ?? 'VACCINE';
    _date = DateTime.tryParse(r?.administeredDate ?? '') ?? DateTime.now();
    _next = DateTime.tryParse(r?.nextDueDate ?? '');
  }

  @override
  void dispose() {
    for (final c in [_title, _vet, _clinic, _notes, _cost]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_next != null && _next!.isBefore(_date)) {
      setState(() => _error = 'Ngày hẹn phải từ ngày khám trở đi.');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<PetProvider>().addHealthRecord(
        HealthRecord(
          id: widget.record?.id,
          petId: widget.petId,
          recordType: _type,
          title: _title.text.trim(),
          administeredDate: DateFormat('yyyy-MM-dd').format(_date),
          nextDueDate: _next == null
              ? null
              : DateFormat('yyyy-MM-dd').format(_next!),
          veterinarian: _vet.text.trim(),
          clinicName: _clinic.text.trim(),
          notes: _notes.text.trim(),
          cost: double.parse(_cost.text.replaceAll(',', '.')),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.record == null ? 'Thêm sổ sức khỏe' : 'Sửa sổ sức khỏe'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Loại hồ sơ'),
              items: const [
                DropdownMenuItem(value: 'VACCINE', child: Text('Tiêm phòng')),
                DropdownMenuItem(value: 'DEWORMING', child: Text('Tẩy giun')),
                DropdownMenuItem(value: 'CHECKUP', child: Text('Khám bệnh')),
                DropdownMenuItem(value: 'SURGERY', child: Text('Phẫu thuật')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Nội dung'),
              validator: (v) =>
                  (v?.trim().isNotEmpty ?? false) ? null : 'Nhập nội dung',
            ),
            ListTile(
              title: const Text('Ngày thực hiện'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(1980),
                  lastDate: DateTime.now(),
                );
                if (d != null && mounted) setState(() => _date = d);
              },
            ),
            ListTile(
              title: const Text('Ngày hẹn tiếp theo'),
              subtitle: Text(
                _next == null
                    ? 'Chưa đặt'
                    : DateFormat('dd/MM/yyyy').format(_next!),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _next = null),
              ),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _next ?? DateTime.now(),
                  firstDate: DateTime(1980),
                  lastDate: DateTime(2100),
                );
                if (d != null && mounted) setState(() => _next = d);
              },
            ),
            TextFormField(
              controller: _vet,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Bác sĩ'),
            ),
            TextFormField(
              controller: _clinic,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Phòng khám'),
            ),
            TextFormField(
              controller: _cost,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Chi phí (đ)'),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                return n == null || !n.isFinite || n < 0
                    ? 'Chi phí không hợp lệ'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLength: 2000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
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
