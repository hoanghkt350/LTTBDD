import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/pet_provider.dart';
import '../../widgets/appointment_status_badge.dart';
import 'pet_detail_screen.dart';

class HealthAppointmentsSection extends StatelessWidget {
  const HealthAppointmentsSection({super.key, this.limit});
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final pending = context
        .watch<PetProvider>()
        .appointments
        .where((appointment) => !appointment.record.nextDueCompleted)
        .toList();
    final visible = limit == null ? pending : pending.take(limit!);
    if (pending.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Chưa có lịch hẹn đang chờ. Thêm ngày hẹn tiếp theo trong sổ sức khỏe của bé.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final appointment in visible)
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: Text(
                '${appointment.pet.name} • ${appointment.record.title}',
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ngày hẹn: ${DateFormat('dd/MM/yyyy').format(appointment.date)}',
                  ),
                  AppointmentStatusBadge(
                    status: appointment.status(DateTime.now()),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PetDetailScreen(pet: appointment.pet),
                ),
              ),
            ),
          ),
        if (limit != null && pending.length > limit!)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Còn ${pending.length - limit!} lịch hẹn trong mục Thú cưng.',
            ),
          ),
      ],
    );
  }
}
