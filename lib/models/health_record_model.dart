class HealthRecord {
  final int? id;
  final int petId;
  final String recordType; // 'VACCINE', 'DEWORMING', 'CHECKUP', 'SURGERY'
  final String title;
  final String administeredDate;
  final String? nextDueDate;
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
      veterinarian: map['veterinarian'] as String?,
      clinicName: map['clinic_name'] as String?,
      notes: map['notes'] as String?,
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
