import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/pet_model.dart';
import '../../providers/pet_provider.dart';
import '../../services/app_error.dart';
import '../../services/health_appointments.dart';
import '../../widgets/appointment_status_badge.dart';
import 'add_pet_screen.dart';
import 'pet_avatar.dart';
import 'health_record_dialog.dart';

class PetDetailScreen extends StatelessWidget {
  final Pet pet;
  const PetDetailScreen({super.key, required this.pet});
  Future<void> _delete(BuildContext context, PetProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa hồ sơ thú cưng?'),
        content: const Text(
          'Sổ sức khỏe và lịch nhắc của thú cưng này cũng sẽ bị xóa khi đồng bộ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await provider.deletePet(pet.id!);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetProvider>();
    final matches = provider.pets.where((p) => p.id == pet.id);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Hồ sơ đã được xóa.')),
      );
    }
    final current = matches.first;
    final records = provider.getRecordsForPet(pet.id!);
    final locked = provider.isLoading || provider.isSyncing;
    final currency = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(current.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: locked
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPetScreen(pet: current),
                    ),
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: locked ? null : () => _delete(context, provider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: PetAvatar(pet: current, radius: 52)),
          const SizedBox(height: 16),
          Text(
            '${current.species} • ${current.breed} • ${current.gender}',
            textAlign: TextAlign.center,
          ),
          Text(
            'Ngày sinh: ${current.birthDate} • ${current.weight} kg',
            textAlign: TextAlign.center,
          ),
          if (current.microchipId?.isNotEmpty ?? false)
            Text(
              'Microchip: ${current.microchipId}',
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),
          if (provider.notificationError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                provider.notificationError!,
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sổ sức khỏe',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: locked
                    ? null
                    : () => showDialog(
                        context: context,
                        builder: (_) => HealthRecordDialog(petId: current.id!),
                      ),
              ),
            ],
          ),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Chưa có hồ sơ sức khỏe.'),
            ),
          ...records.map(
            (r) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text('Ngày thực hiện: ${r.administeredDate}'),
                    if (DateTime.tryParse(r.nextDueDate ?? '') != null) ...[
                      Text('Hẹn tiếp theo: ${r.nextDueDate}'),
                      AppointmentStatusBadge(
                        status: HealthAppointment(
                          record: r,
                          pet: current,
                        ).status(DateTime.now()),
                      ),
                      Text(
                        r.nextDueCompleted
                            ? 'Lịch hẹn đã hoàn tất, thông báo đã dừng.'
                            : r.nextDueReminderEnabled
                            ? 'Nhắc lúc ${r.nextDueReminderTime} trước 1 ngày và vào ngày hẹn.'
                            : 'Đã tắt nhắc lịch hẹn.',
                      ),
                    ],
                    if (r.veterinarian?.isNotEmpty ?? false)
                      Text('Bác sĩ: ${r.veterinarian}'),
                    if (r.clinicName?.isNotEmpty ?? false)
                      Text('Phòng khám: ${r.clinicName}'),
                    Text('Chi phí: ${currency.format(r.cost)}'),
                    if (r.notes?.isNotEmpty ?? false) Text(r.notes!),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        if (r.nextDueDate != null)
                          TextButton.icon(
                            icon: Icon(
                              r.nextDueCompleted
                                  ? Icons.undo
                                  : Icons.check_circle_outline,
                            ),
                            label: Text(
                              r.nextDueCompleted
                                  ? 'Mở lại lịch hẹn'
                                  : 'Đánh dấu đã thực hiện',
                            ),
                            onPressed: locked
                                ? null
                                : () async {
                                    try {
                                      await provider.completeAppointment(
                                        r.id!,
                                        !r.nextDueCompleted,
                                      );
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(errorMessage(error)),
                                          ),
                                        );
                                      }
                                    }
                                  },
                          ),
                        TextButton(
                          onPressed: locked
                              ? null
                              : () => showDialog(
                                  context: context,
                                  builder: (_) => HealthRecordDialog(
                                    petId: current.id!,
                                    record: r,
                                  ),
                                ),
                          child: const Text('Sửa'),
                        ),
                        TextButton(
                          onPressed: locked
                              ? null
                              : () async {
                                  try {
                                    await provider.deleteHealthRecord(r.id!);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(errorMessage(e)),
                                            ),
                                          );
                                    }
                                  }
                                },
                          child: const Text('Xóa'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
