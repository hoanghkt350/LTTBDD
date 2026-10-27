import 'package:flutter/material.dart';
import '../models/pet_model.dart';
import '../models/health_record_model.dart';
import '../models/reminder_model.dart';
import '../services/database_helper.dart';
import '../services/firebase_mock_service.dart';

class PetProvider with ChangeNotifier {
  List<Pet> _pets = [];
  List<Reminder> _reminders = [];
  Map<int, List<HealthRecord>> _petHealthRecords = {};
  bool _isLoading = false;
  bool _isSyncing = false;

  List<Pet> get pets => [..._pets];
  List<Reminder> get reminders => [..._reminders];
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;

  Future<void> loadInitialData() async {
    _isLoading = true;
    notifyListeners();

    _pets = await DatabaseHelper.instance.getPets();
    _reminders = await DatabaseHelper.instance.getReminders();

    // Load health records for each pet
    for (var pet in _pets) {
      if (pet.id != null) {
        _petHealthRecords[pet.id!] =
            await DatabaseHelper.instance.getHealthRecordsByPet(pet.id!);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  List<HealthRecord> getRecordsForPet(int petId) {
    return _petHealthRecords[petId] ?? [];
  }

  Future<void> addPet(Pet pet) async {
    final id = await DatabaseHelper.instance.insertPet(pet);
    final newPet = pet.copyWith(id: id);
    _pets.insert(0, newPet);
    _petHealthRecords[id] = [];
    notifyListeners();
  }

  Future<void> deletePet(int id) async {
    await DatabaseHelper.instance.deletePet(id);
    _pets.removeWhere((p) => p.id == id);
    _petHealthRecords.remove(id);
    _reminders.removeWhere((r) => r.petId == id);
    notifyListeners();
  }

  Future<void> addHealthRecord(HealthRecord record) async {
    final id = await DatabaseHelper.instance.insertHealthRecord(record);
    final newRecord = HealthRecord(
      id: id,
      petId: record.petId,
      recordType: record.recordType,
      title: record.title,
      administeredDate: record.administeredDate,
      nextDueDate: record.nextDueDate,
      veterinarian: record.veterinarian,
      clinicName: record.clinicName,
      notes: record.notes,
      cost: record.cost,
    );

    if (!_petHealthRecords.containsKey(record.petId)) {
      _petHealthRecords[record.petId] = [];
    }
    _petHealthRecords[record.petId]!.insert(0, newRecord);
    notifyListeners();
  }

  Future<void> addReminder(Reminder reminder) async {
    final id = await DatabaseHelper.instance.insertReminder(reminder);
    final newReminder = Reminder(
      id: id,
      petId: reminder.petId,
      title: reminder.title,
      reminderTime: reminder.reminderTime,
      repeatInterval: reminder.repeatInterval,
      notificationId: reminder.notificationId,
      isActive: reminder.isActive,
    );
    _reminders.add(newReminder);
    notifyListeners();
  }

  Future<void> toggleReminder(int id, bool active) async {
    await DatabaseHelper.instance.toggleReminderActive(id, active);
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      final old = _reminders[index];
      _reminders[index] = Reminder(
        id: old.id,
        petId: old.petId,
        title: old.title,
        reminderTime: old.reminderTime,
        repeatInterval: old.repeatInterval,
        notificationId: old.notificationId,
        isActive: active ? 1 : 0,
      );
      notifyListeners();
    }
  }

  Future<void> deleteReminder(int id) async {
    await DatabaseHelper.instance.deleteReminder(id);
    _reminders.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  // Đồng bộ SQFlite lên Firebase Cloud
  Future<bool> syncDataToCloud() async {
    _isSyncing = true;
    notifyListeners();

    final success = await FirebaseService.instance.syncLocalPetsToCloud(_pets.length);

    _isSyncing = false;
    notifyListeners();
    return success;
  }
}
