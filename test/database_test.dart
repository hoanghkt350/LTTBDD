import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pawpals_app/services/database_helper.dart';

void main() {
  sqfliteFfiInit();
  late Database database;
  late DatabaseHelper store;
  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.createSchema(database);
    store = DatabaseHelper('alice', suppliedDatabase: database);
  });
  tearDown(() async {
    await database.close();
  });
  test('saving an entity and its outbox entry is atomic', () async {
    await store.put('pets', {'id': 1, 'name': 'Milo'});
    expect((await store.read('pets')).single['name'], 'Milo');
    expect((await store.pending()).single['id'], 1);
  });
  test('acknowledging an old upload never removes a newer edit', () async {
    await store.put('pets', {'id': 1, 'name': 'Milo'});
    final old = (await store.pending()).single;
    await store.put('pets', {'id': 1, 'name': 'Milo edited'});
    await store.acknowledge(old);
    expect(await store.pending(), hasLength(1));
    expect((await store.read('pets')).single['name'], 'Milo edited');
  });
  test('cloud refresh cannot overwrite unsent local data', () async {
    await store.put('pets', {'id': 1, 'name': 'Offline edit'});
    await store.replaceFromCloud({
      'pets': [
        {'id': 1, 'name': 'Old cloud data'},
      ],
    });
    expect((await store.read('pets')).single['name'], 'Offline edit');
  });
  test(
    'pet deletion queues tombstones for health records and reminders',
    () async {
      await store.put('pets', {'id': 1, 'name': 'Milo'});
      await store.put('health_records', {
        'id': 2,
        'pet_id': 1,
        'title': 'Vaccine',
      });
      await store.put('reminders', {'id': 3, 'pet_id': 1, 'title': 'Food'});
      await store.remove('pets', 1);
      expect(await store.read('pets'), isEmpty);
      expect(await store.read('health_records'), isEmpty);
      expect(await store.read('reminders'), isEmpty);
      final pending = await store.pending();
      expect(pending, hasLength(3));
      for (final row in pending) {
        expect(row['payload'], contains('"deleted":true'));
      }
    },
  );
  test(
    'acknowledged deletes remain deleted when cloud tombstones are pulled',
    () async {
      await store.put('pets', {'id': 1, 'name': 'Milo'});
      await store.remove('pets', 1);
      for (final row in await store.pending()) {
        await store.acknowledge(row);
      }
      await store.replaceFromCloud({
        'pets': [
          {'id': 1, 'deleted': true},
        ],
      });
      expect(await store.read('pets'), isEmpty);
      expect(await store.pending(), isEmpty);
    },
  );
  test('cloud refresh restores three collections together', () async {
    await store.replaceFromCloud({
      'pets': [
        {'id': 1, 'name': 'Milo'},
      ],
      'health_records': [
        {'id': 2, 'pet_id': 1, 'title': 'Vaccine'},
      ],
      'reminders': [
        {'id': 3, 'pet_id': 1, 'title': 'Food'},
      ],
    });
    expect(await store.read('pets'), hasLength(1));
    expect(await store.read('health_records'), hasLength(1));
    expect(await store.read('reminders'), hasLength(1));
  });
}
