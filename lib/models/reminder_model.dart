class Reminder {
  final int? id;
  final int petId;
  final String title;
  final String reminderTime; // '08:00'
  final String repeatInterval; // 'DAILY', 'WEEKLY', 'NONE'
  final int notificationId;
  final int isActive; // 1 or 0

  Reminder({
    this.id,
    required this.petId,
    required this.title,
    required this.reminderTime,
    this.repeatInterval = 'DAILY',
    required this.notificationId,
    this.isActive = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pet_id': petId,
      'title': title,
      'reminder_time': reminderTime,
      'repeat_interval': repeatInterval,
      'notification_id': notificationId,
      'is_active': isActive,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as int?,
      petId: map['pet_id'] as int,
      title: map['title'] as String,
      reminderTime: map['reminder_time'] as String,
      repeatInterval: (map['repeat_interval'] as String?) ?? 'DAILY',
      notificationId: (map['notification_id'] as int?) ?? 0,
      isActive: (map['is_active'] as int?) ?? 1,
    );
  }
}
