import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Each Firebase UID has an independent database. Legacy demo data is untouched.
/// Local changes and their outbox entry are committed in the same SQL transaction.
class DatabaseHelper {
  final String userId;
  final Database? suppliedDatabase;
  DatabaseHelper(this.userId, {this.suppliedDatabase});
  Future<Database>? _opening;
  Future<Database> get database => _opening ??= _open();
  Future<Database> _open() async {
    if (suppliedDatabase != null) return suppliedDatabase!;
    final safeId = base64Url.encode(utf8.encode(userId)).replaceAll('=', '');
    return openDatabase(
      path.join(await getDatabasesPath(), 'pawpals_$safeId.db'),
      version: 1,
      onCreate: (db, _) => createSchema(db),
    );
  }

  static Future<void> createSchema(Database db) async {
    await db.execute(
      'CREATE TABLE entities (collection TEXT NOT NULL, id INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(collection,id))',
    );
    await db.execute(
      'CREATE TABLE outbox (collection TEXT NOT NULL, id INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(collection,id))',
    );
  }

  Future<List<Map<String, dynamic>>> read(String collection) async {
    final rows = await (await database).query(
      'entities',
      where: 'collection = ?',
      whereArgs: [collection],
    );
    return rows
        .map(
          (r) => Map<String, dynamic>.from(jsonDecode(r['payload'] as String)),
        )
        .toList();
  }

  Future<void> _put(
    Transaction tx,
    String collection,
    Map<String, dynamic> data, {
    bool deleted = false,
  }) async {
    final id = data['id'] as int;
    final payload = jsonEncode(deleted ? {'id': id, 'deleted': true} : data);
    if (deleted) {
      await tx.delete(
        'entities',
        where: 'collection = ? AND id = ?',
        whereArgs: [collection, id],
      );
    } else {
      await tx.insert('entities', {
        'collection': collection,
        'id': id,
        'payload': payload,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await tx.insert('outbox', {
      'collection': collection,
      'id': id,
      'payload': payload,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> put(String collection, Map<String, dynamic> data) async {
    await (await database).transaction((tx) => _put(tx, collection, data));
  }

  Future<void> remove(String collection, int id) async {
    await (await database).transaction((tx) async {
      if (collection == 'pets') {
        for (final child in ['health_records', 'reminders']) {
          final rows = await tx.query(
            'entities',
            where: 'collection = ?',
            whereArgs: [child],
          );
          for (final row in rows) {
            final data = Map<String, dynamic>.from(
              jsonDecode(row['payload'] as String),
            );
            if (data['pet_id'] == id) {
              await _put(tx, child, data, deleted: true);
            }
          }
        }
      }
      await _put(tx, collection, {'id': id}, deleted: true);
    });
  }

  Future<List<Map<String, Object?>>> pending() async =>
      (await database).query('outbox');
  Future<void> acknowledge(Map<String, Object?> entry) async {
    await (await database).delete(
      'outbox',
      where: 'collection = ? AND id = ? AND payload = ?',
      whereArgs: [entry['collection'], entry['id'], entry['payload']],
    );
  }

  Future<void> replaceFromCloud(
    Map<String, List<Map<String, dynamic>>> collections,
  ) async {
    await (await database).transaction((tx) async {
      // Never overwrite a mutation made while the network was in flight.
      if ((await tx.query('outbox', limit: 1)).isNotEmpty) return;
      await tx.delete('entities');
      for (final entry in collections.entries) {
        for (final data in entry.value) {
          if (data['deleted'] == true) continue;
          await tx.insert('entities', {
            'collection': entry.key,
            'id': data['id'],
            'payload': jsonEncode(data),
          });
        }
      }
    });
  }

  Future<void> close() async {
    if (_opening != null) await (await _opening!).close();
  }
}
