import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/pet_model.dart';
import '../models/health_record_model.dart';
import '../models/reminder_model.dart';
import '../services/database_helper.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/app_error.dart';

class PetProvider with ChangeNotifier {
  final DatabaseHelper store;
  PetProvider(String uid) : store = DatabaseHelper(uid);
  List<Pet> _pets = [];
  List<Reminder> _reminders = [];
  final Map<int, List<HealthRecord>> _records = {};
  bool _isLoading = false, _isSyncing = false, _disposed = false;
  String? error, syncError, notificationError;
  int pendingCount = 0;
  bool _loaded = false;
  List<Pet> get pets => List.unmodifiable(_pets);
  List<Reminder> get reminders => List.unmodifiable(_reminders);
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static int newId() {
    final random = Random.secure();
    return random.nextInt(1 << 26) * (1 << 26) + random.nextInt(1 << 26);
  }

  void _editable() {
    if (_isSyncing || _isLoading) {
      throw StateError('Đang tải hoặc đồng bộ. Vui lòng thử lại sau.');
    }
  }

  List<HealthRecord> getRecordsForPet(int id) =>
      List.unmodifiable(_records[id] ?? []);
  Future<void> _read() async {
    _pets = (await store.read('pets')).map(Pet.fromMap).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final valid = _pets.map((p) => p.id).toSet();
    _reminders =
        (await store.read('reminders'))
            .map(Reminder.fromMap)
            .where((r) => valid.contains(r.petId))
            .toList()
          ..sort((a, b) => a.reminderTime.compareTo(b.reminderTime));
    _records.clear();
    for (final row in await store.read('health_records')) {
      final record = HealthRecord.fromMap(row);
      if (valid.contains(record.petId)) {
        (_records[record.petId] ??= []).add(record);
      }
    }
    for (final records in _records.values) {
      records.sort((a, b) => b.administeredDate.compareTo(a.administeredDate));
    }
    pendingCount = (await store.pending()).length;
  }

  Future<void> _notifications({bool requestPermission = false}) async {
    if (_disposed) return;
    try {
      await NotificationService.instance.replace(
        _reminders,
        requestPermission:
            requestPermission && _reminders.any((r) => r.isActive == 1),
      );
      notificationError = null;
    } catch (e) {
      notificationError = errorMessage(e);
    }
  }

  Future<void> loadInitialData() async {
    if (_isLoading || _loaded) return;
    _isLoading = true;
    error = null;
    _notify();
    try {
      await _read();
      _loaded = true;
      await _notifications();
    } catch (e) {
      error = errorMessage(e);
    } finally {
      _isLoading = false;
      _notify();
    }
    if (_loaded && !_disposed) unawaited(syncDataToCloud());
  }

  Future<void> _changed({
    bool remindersChanged = false,
    bool requestPermission = false,
  }) async {
    await _read();
    if (remindersChanged) {
      await _notifications(requestPermission: requestPermission);
    }
    _notify();
    // Offline edits remain in the persistent outbox until the next sync.
  }

  Future<void> addPet(Pet pet) async {
    _editable();
    await store.put(
      'pets',
      pet.copyWith(id: pet.id ?? newId(), isSynced: 0).toMap(),
    );
    await _changed();
  }

  Future<void> updatePet(Pet pet) async {
    _editable();
    if (!_pets.any((p) => p.id == pet.id)) {
      throw StateError('Hồ sơ không tồn tại.');
    }
    await store.put('pets', pet.copyWith(isSynced: 0).toMap());
    await _changed();
  }

  Future<void> deletePet(int id) async {
    _editable();
    await store.remove('pets', id);
    await _changed(remindersChanged: true);
  }

  Future<void> addHealthRecord(HealthRecord record) async {
    _editable();
    if (!_pets.any((p) => p.id == record.petId)) {
      throw StateError('Thú cưng không còn tồn tại.');
    }
    await store.put('health_records', {
      ...record.toMap(),
      'id': record.id ?? newId(),
    });
    await _changed();
  }

  Future<void> deleteHealthRecord(int id) async {
    _editable();
    await store.remove('health_records', id);
    await _changed();
  }

  Future<void> addReminder(Reminder reminder) async {
    _editable();
    if (!_pets.any((p) => p.id == reminder.petId)) {
      throw StateError('Thú cưng không còn tồn tại.');
    }
    if (_reminders.length >= 50 && reminder.id == null) {
      throw StateError('Tối đa 50 lịch nhắc.');
    }
    final id = reminder.id ?? newId();
    await store.put('reminders', {
      ...reminder.toMap(),
      'id': id,
      'notification_id': id % 2147483647,
    });
    await _changed(
      remindersChanged: true,
      requestPermission: reminder.isActive == 1,
    );
  }

  Future<void> toggleReminder(int id, bool active) async {
    _editable();
    final reminder = _reminders.firstWhere((r) => r.id == id);
    await store.put('reminders', {
      ...reminder.toMap(),
      'is_active': active ? 1 : 0,
    });
    await _changed(remindersChanged: true, requestPermission: active);
  }

  Future<void> deleteReminder(int id) async {
    _editable();
    await store.remove('reminders', id);
    await _changed(remindersChanged: true);
  }

  Future<bool> syncDataToCloud() async {
    if (_isSyncing || _isLoading || _disposed) return false;
    _isSyncing = true;
    syncError = null;
    _notify();
    try {
      final service = FirebaseService.instance;
      if (service.uid != store.userId) {
        throw StateError('Phiên đăng nhập đã thay đổi.');
      }
      final ownerDocument = service.firestore
          .collection('users')
          .doc(store.userId);
      for (final entry in await store.pending()) {
        if (_disposed) return false;
        final data = Map<String, dynamic>.from(
          jsonDecode(entry['payload'] as String),
        );
        data.remove(
          'avatar_path',
        ); // Device-specific paths must never leave this device.
        await ownerDocument
            .collection(entry['collection'] as String)
            .doc(entry['id'].toString())
            .set({...data, 'updatedAt': FieldValue.serverTimestamp()})
            .timeout(const Duration(seconds: 12));
        await store.acknowledge(entry);
      }
      final cloud = <String, List<Map<String, dynamic>>>{};
      for (final collection in ['pets', 'health_records', 'reminders']) {
        if (_disposed) return false;
        final snapshot = await ownerDocument
            .collection(collection)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 12));
        cloud[collection] = snapshot.docs.map((d) {
          final data = d.data()..remove('updatedAt');
          if (collection == 'pets') data['is_synced'] = 1;
          return data;
        }).toList();
      }
      if (_disposed) return false;
      await store.replaceFromCloud(cloud);
      await _read();
      await _notifications();
      return true;
    } catch (e) {
      syncError = errorMessage(e);
      return false;
    } finally {
      _isSyncing = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(NotificationService.instance.clear().catchError((Object _) {}));
    unawaited(store.close().catchError((Object _) {}));
    super.dispose();
  }
}
