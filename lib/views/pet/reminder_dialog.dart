import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/reminder_model.dart';
import '../../providers/pet_provider.dart';
import '../../services/app_error.dart';

class ReminderDialog extends StatefulWidget {
  final Reminder? reminder;
  const ReminderDialog({super.key, this.reminder});
  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  late final TextEditingController _title;
  late int _petId;
  late TimeOfDay _time;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _title = TextEditingController(text: r?.title);
    _petId = r?.petId ?? context.read<PetProvider>().pets.first.id!;
    final parts = (r?.reminderTime ?? '08:00').split(':');
    _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Nhập nội dung nhắc.');
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<PetProvider>();
    try {
      await provider.addReminder(
        Reminder(
          id: widget.reminder?.id,
          petId: _petId,
          title: _title.text.trim(),
          reminderTime:
              '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
          notificationId: widget.reminder?.notificationId ?? 0,
          isActive: widget.reminder?.isActive ?? 1,
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
    title: Text(widget.reminder == null ? 'Thêm lịch nhắc' : 'Sửa lịch nhắc'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _petId,
            decoration: const InputDecoration(labelText: 'Thú cưng'),
            items: context
                .read<PetProvider>()
                .pets
                .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                .toList(),
            onChanged: _saving ? null : (v) => setState(() => _petId = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            maxLength: 150,
            decoration: const InputDecoration(labelText: 'Nội dung'),
          ),
          ListTile(
            title: const Text('Nhắc hàng ngày'),
            subtitle: Text(_time.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: _saving
                ? null
                : () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (time != null && mounted) setState(() => _time = time);
                  },
          ),
          const Text(
            'Thông báo có thể trễ vài phút tùy chế độ tiết kiệm pin của thiết bị.',
            style: TextStyle(fontSize: 12),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
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
