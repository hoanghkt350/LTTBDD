class HealthRecord {
  final int? id;
  final int petId;
  final String recordType; // 'VACCINE', 'DEWORMING', 'CHECKUP', 'SURGERY'
  final String title;
  final String administeredDate;
  final String? nextDueDate;
  final bool nextDueReminderEnabled;
  final String nextDueReminderTime;
  final bool nextDueCompleted;
  final String? veterinarian;
  final String? clinicName;
  final String? notes;
  final double cost;

  HealthRecord({
    this.id,
    required this.petId,
    required this.recordType,
    required this.title,
    required this.administeredDate,
    this.nextDueDate,
    this.nextDueReminderEnabled = true,
    this.nextDueReminderTime = '08:00',
    this.nextDueCompleted = false,
    this.veterinarian,
    this.clinicName,
    this.notes,
    this.cost = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pet_id': petId,
      'record_type': recordType,
      'title': title,
      'administered_date': administeredDate,
      'next_due_date': nextDueDate,
      'next_due_reminder_enabled': nextDueReminderEnabled,
      'next_due_reminder_time': nextDueReminderTime,
      'next_due_completed': nextDueCompleted,
      'veterinarian': veterinarian,
      'clinic_name': clinicName,
      'notes': notes,
      'cost': cost,
    };
  }

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      id: map['id'] as int?,
      petId: map['pet_id'] as int,
      recordType: map['record_type'] as String,
      title: map['title'] as String,
      administeredDate: map['administered_date'] as String,
      nextDueDate: map['next_due_date'] as String?,
      nextDueReminderEnabled: map['next_due_reminder_enabled'] as bool? ?? true,
      nextDueReminderTime: map['next_due_reminder_time'] as String? ?? '08:00',
      nextDueCompleted: map['next_due_completed'] as bool? ?? false,
      veterinarian: map['veterinarian'] as String?,
      clinicName: map['clinic_name'] as String?,
      notes: map['notes'] as String?,
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
