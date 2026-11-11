import '../models/health_record_model.dart';
import '../models/pet_model.dart';

enum AppointmentStatus {
  scheduled('Đã lên lịch'),
  upcoming('Sắp đến hạn'),
  today('Đến hạn hôm nay'),
  overdue('Quá hạn'),
  completed('Đã thực hiện');

  const AppointmentStatus(this.label);
  final String label;
}

class HealthAppointment {
  const HealthAppointment({required this.record, required this.pet});
  final HealthRecord record;
  final Pet pet;

  DateTime get date => DateTime.parse(record.nextDueDate!);

  AppointmentStatus status(DateTime now) {
    if (record.nextDueCompleted) return AppointmentStatus.completed;
    final today = DateTime.utc(now.year, now.month, now.day);
    final due = DateTime.utc(date.year, date.month, date.day);
    final days = due.difference(today).inDays;
    if (days < 0) return AppointmentStatus.overdue;
    if (days == 0) return AppointmentStatus.today;
    if (days <= 7) return AppointmentStatus.upcoming;
    return AppointmentStatus.scheduled;
  }
}
