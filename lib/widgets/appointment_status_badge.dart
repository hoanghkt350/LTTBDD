import 'package:flutter/material.dart';

import '../services/health_appointments.dart';

class AppointmentStatusBadge extends StatelessWidget {
  const AppointmentStatusBadge({super.key, required this.status});
  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AppointmentStatus.overdue => Colors.red.shade700,
      AppointmentStatus.today => Colors.orange.shade900,
      AppointmentStatus.upcoming => Colors.blue.shade700,
      AppointmentStatus.completed => Colors.green.shade700,
      AppointmentStatus.scheduled => Colors.blueGrey.shade700,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            status.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
