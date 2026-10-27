import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/pet_model.dart';
import '../models/health_record_model.dart';
import '../models/reminder_model.dart';

class DatabaseHelper {
  static const _databaseName = "pawpals_local.db";
  static const _databaseVersion = 1;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    // 1. Bảng pets
    await db.execute('''
      CREATE TABLE pets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT,
        name TEXT NOT NULL,
        species TEXT NOT NULL,
        breed TEXT NOT NULL,
        gender TEXT NOT NULL,
        birth_date TEXT NOT NULL,
        weight REAL NOT NULL,
        microchip_id TEXT,
        avatar_path TEXT,
        avatar_cloud_url TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // 2. Bảng health_records
    await db.execute('''
      CREATE TABLE health_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pet_id INTEGER NOT NULL,
        record_type TEXT NOT NULL,
        title TEXT NOT NULL,
        administered_date TEXT NOT NULL,
        next_due_date TEXT,
        veterinarian TEXT,
        clinic_name TEXT,
        notes TEXT,
        cost REAL DEFAULT 0.0,
        FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE
      )
    ''');

    // 3. Bảng reminders
    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pet_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        reminder_time TEXT NOT NULL,
        repeat_interval TEXT DEFAULT 'DAILY',
        notification_id INTEGER,
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE
      )
    ''');

    // Chèn dữ liệu mẫu ban đầu để demo chạy mượt mà ngay
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    // Pet mẫu 1
    int pet1Id = await db.insert('pets', {
      'name': 'Milo',
      'species': 'Chó',
      'breed': 'Golden Retriever',
      'gender': 'Đực',
      'birth_date': '2023-04-12',
      'weight': 24.5,
      'microchip_id': 'VN-982001',
      'avatar_cloud_url': 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=400&q=80',
      'is_synced': 1,
    });

    // Pet mẫu 2
    int pet2Id = await db.insert('pets', {
      'name': 'Luna',
      'species': 'Mèo',
      'breed': 'Mèo Anh Lông Ngắn',
      'gender': 'Cái',
      'birth_date': '2024-01-10',
      'weight': 4.2,
      'microchip_id': 'VN-982002',
      'avatar_cloud_url': 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=400&q=80',
      'is_synced': 1,
    });

    // Health records mẫu
    await db.insert('health_records', {
      'pet_id': pet1Id,
      'record_type': 'VACCINE',
      'title': 'Tiêm phòng 7 bệnh chó (Mũi 2)',
      'administered_date': '2026-08-15',
      'next_due_date': '2027-08-15',
      'veterinarian': 'BS. Lê Minh',
      'clinic_name': 'PetCare Sài Gòn',
      'notes': 'Bé ngoan, không bị sốt sau tiêm',
      'cost': 250000,
    });

    await db.insert('health_records', {
      'pet_id': pet2Id,
      'record_type': 'DEWORMING',
      'title': 'Tẩy giun định kỳ Drontal',
      'administered_date': '2026-09-01',
      'next_due_date': '2026-12-01',
      'veterinarian': 'BS. Hoàng Yến',
      'clinic_name': 'Phòng khám AniVet',
      'notes': 'Uống 1/2 viên',
      'cost': 60000,
    });

    // Reminders mẫu
    await db.insert('reminders', {
      'pet_id': pet1Id,
      'title': 'Cho Milo ăn bữa sáng',
      'reminder_time': '07:30',
      'repeat_interval': 'DAILY',
      'notification_id': 101,
      'is_active': 1,
    });

    await db.insert('reminders', {
      'pet_id': pet2Id,
      'title': 'Vệ sinh khay cát & chải lông cho Luna',
      'reminder_time': '19:00',
      'repeat_interval': 'DAILY',
      'notification_id': 102,
      'is_active': 1,
    });
  }

  // --- CRUD PETS ---
  Future<int> insertPet(Pet pet) async {
    final db = await database;
    return await db.insert('pets', pet.toMap());
  }

  Future<List<Pet>> getPets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('pets', orderBy: 'id DESC');
    return maps.map((map) => Pet.fromMap(map)).toList();
  }

  Future<int> updatePet(Pet pet) async {
    final db = await database;
    return await db.update(
      'pets',
      pet.toMap(),
      where: 'id = ?',
      whereArgs: [pet.id],
    );
  }

  Future<int> deletePet(int id) async {
    final db = await database;
    return await db.delete('pets', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD HEALTH RECORDS ---
  Future<int> insertHealthRecord(HealthRecord record) async {
    final db = await database;
    return await db.insert('health_records', record.toMap());
  }

  Future<List<HealthRecord>> getHealthRecordsByPet(int petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'health_records',
      where: 'pet_id = ?',
      whereArgs: [petId],
      orderBy: 'administered_date DESC',
    );
    return maps.map((map) => HealthRecord.fromMap(map)).toList();
  }

  // --- CRUD REMINDERS ---
  Future<int> insertReminder(Reminder reminder) async {
    final db = await database;
    return await db.insert('reminders', reminder.toMap());
  }

  Future<List<Reminder>> getReminders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      orderBy: 'reminder_time ASC',
    );
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<int> toggleReminderActive(int id, bool isActive) async {
    final db = await database;
    return await db.update(
      'reminders',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }
}
