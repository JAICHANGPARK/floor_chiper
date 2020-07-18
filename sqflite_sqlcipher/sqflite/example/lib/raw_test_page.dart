import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_sqlcipher_example/src/dev_utils.dart';

import 'test_page.dart';

/// Raw test page.
class RawTestPage extends TestPage {
  /// Raw test page.
  RawTestPage() : super('Raw tests') {
    test('Simple', () async {
      // await Sqflite.devSetDebugModeOn(true);

      var path = await initDeleteDb('raw_simple.db');
      var db = await openDatabase(path);
      try {
        await db
            .execute('CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT)');
        expect(
            await db.rawInsert('INSERT INTO Test (name) VALUES (?)', ['test']),
            1);

        var result = await db.query('Test');
        var expected = [
          {'id': 1, 'name': 'test'}
        ];
        expect(result, expected);
      } finally {
        await db?.close();
      }
    });

    test('Sqlite version', () async {
      var db = await openDatabase(inMemoryDatabasePath);
      var results = await db.rawQuery('select sqlite_version()');
      print('sqlite version: ${results.first.values.first}');
      await db.close();
    });

    test('Transaction', () async {
      //Sqflite.devSetDebugModeOn(true);
      var path = await initDeleteDb('simple_transaction.db');
      var db = await openDatabase(path);
      try {
        await db
            .execute('CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT)');

        Future _test(int i) async {
          await db.transaction((txn) async {
            var count = Sqflite.firstIntValue(
                await txn.rawQuery('SELECT COUNT(*) FROM Test'));
            await Future.delayed(Duration(milliseconds: 40));
            await txn
                .rawInsert('INSERT INTO Test (name) VALUES (?)', ['item $i']);
            //print(await db.query('SELECT COUNT(*) FROM Test'));
            var afterCount = Sqflite.firstIntValue(
                await txn.rawQuery('SELECT COUNT(*) FROM Test'));
            expect(count + 1, afterCount);
          });
        }

        var futures = <Future>[];
        for (var i = 0; i < 4; i++) {
          futures.add(_test(i));
        }
        await Future.wait(futures);
      } finally {
        await db?.close();
      }
    });

    test('Concurrency 1', () async {
      // Sqflite.devSetDebugModeOn(true);
      var path = await initDeleteDb('simple_concurrency_1.db');
      var db = await openDatabase(path);
      try {
        var step1 = Completer();
        var step2 = Completer();
        var step3 = Completer();

        Future action1() async {
          await db
              .execute('CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT)');
          step1.complete();

          await step2.future;
          try {
            await db
                .rawQuery('SELECT COUNT(*) FROM Test')
                .timeout(Duration(seconds: 1));
            throw 'should fail';
          } catch (e) {
            expect(e is TimeoutException, true);
          }

          step3.complete();
        }

        Future action2() async {
          await db.transaction((txn) async {
            // Wait for table being created;
            await step1.future;
            await txn
                .rawInsert('INSERT INTO Test (name) VALUES (?)', ['item 1']);
            step2.complete();

            await step3.future;

            var count = Sqflite.firstIntValue(
                await txn.rawQuery('SELECT COUNT(*) FROM Test'));
            expect(count, 1);
          });
        }

        var future1 = action1();
        var future2 = action2();

        await Future.wait([future1, future2]);

        var count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM Test'));
        expect(count, 1);
      } finally {
        await db?.close();
      }
    });

    test('Concurrency 2', () async {
      // Sqflite.devSetDebugModeOn(true);
      var path = await initDeleteDb('simple_concurrency_2.db');
      var db = await openDatabase(path);
      try {
        var step1 = Completer();
        var step2 = Completer();
        var step3 = Completer();

        Future action1() async {
          await db
              .execute('CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT)');
          step1.complete();

          await step2.future;
          try {
            await db
                .rawQuery('SELECT COUNT(*) FROM Test')
                .timeout(Duration(seconds: 1));
            throw 'should fail';
          } catch (e) {
            expect(e is TimeoutException, true);
          }

          step3.complete();
        }

        Future action2() async {
          // This is the change from concurrency 1
          // Wait for table being created;
          await step1.future;

          await db.transaction((txn) async {
            // Wait for table being created;
            await txn
                .rawInsert('INSERT INTO Test (name) VALUES (?)', ['item 1']);
            step2.complete();

            await step3.future;

            var count = Sqflite.firstIntValue(
                await txn.rawQuery('SELECT COUNT(*) FROM Test'));
            expect(count, 1);
          });
        }

        var future1 = action1();
        var future2 = action2();

        await Future.wait([future1, future2]);

        var count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM Test'));
        expect(count, 1);
      } finally {
        await db?.close();
      }
    });

    test('Transaction recursive', () async {
      var path = await initDeleteDb('transaction_recursive.db');
      var db = await openDatabase(path);
      try {
        await db
            .execute('CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT)');

        // insert then fails to make sure the transaction is cancelled
        await db.transaction((txn) async {
          await txn.rawInsert('INSERT INTO Test (name) VALUES (?)', ['item 1']);

          await txn.rawInsert('INSERT INTO Test (name) VALUES (?)', ['item 2']);
        });
        var afterCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM Test'));
        expect(afterCount, 2);
      } finally {
        await db?.close();
      }
    });

    test('Transaction open twice', () async {
      //Sqflite.devSetDebugModeOn(true);
      var path = await initDeleteDb('transaction_open_twice.db');
      var db = await openDatabase(path);
      Database db2;
      try {
        await db
            .execute('CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT)');

        db2 = await openDatabase(path);

        await db.transaction((txn) async {
          await txn.rawInsert('INSERT INTO Test (name) VALUES (?)', ['item']);
          var afterCount = Sqflite.firstIntValue(
              await txn.rawQuery('SELECT COUNT(*) FROM Test'));
          expect(afterCount, 1);

          /*
        // this is not working on Android
        int db2AfterCount =
        Sqflite.firstIntValue(await db2.rawQuery('SELECT COUNT(*) FROM Test'));
        assert(db2AfterCount == 0);
        */
        });
        var db2AfterCount = Sqflite.firstIntValue(
            await db2.rawQuery('SELECT COUNT(*) FROM Test'));
        expect(db2AfterCount, 1);

        var afterCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM Test'));
        expect(afterCount, 1);
      } finally {
        await db?.close();
        await db2?.close();
      }
    });

    test('Debug mode (log)', () async {
      //await Sqflite.devSetDebugModeOn(false);
      var path = await initDeleteDb('debug_mode.db');
      var db = await openDatabase(path);
      try {
        var debugModeOn = await Sqflite.getDebugModeOn();
        await Sqflite.setDebugModeOn(true);
        await db.setVersion(1);
        await Sqflite.setDebugModeOn(false);
        // this message should not appear
        await db.setVersion(2);
        await Sqflite.setDebugModeOn(true);
        await db.setVersion(3);
        // restore
        await Sqflite.setDebugModeOn(debugModeOn);
      } finally {
        await db?.close();
      }
    });

    test('Demo', () async {
      // await Sqflite.devSetDebugModeOn();
      var path = await initDeleteDb('simple_demo.db');
      var database = await openDatabase(path);
      try {
        //int version = await database.update('PRAGMA user_version');
        //print('version: ${await database.update('PRAGMA user_version')}');
        print('version: ${await database.rawQuery('PRAGMA user_version')}');

        //print('drop: ${await database.update('DROP TABLE IF EXISTS Test')}');
        await database.execute('DROP TABLE IF EXISTS Test');

        print('dropped');
        await database.execute(
            'CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT, value INTEGER, num REAL)');
        print('table created');
        var id = await database.rawInsert(
            'INSERT INTO Test(name, value, num) VALUES("some name",1234,?)',
            [456.789]);
        print('inserted1: $id');
        id = await database.rawInsert(
            'INSERT INTO Test(name, value) VALUES(?, ?)',
            ['another name', 12345678]);
        print('inserted2: $id');
        var count = await database.rawUpdate(
            'UPDATE Test SET name = ?, value = ? WHERE name = ?',
            ['updated name', '9876', 'some name']);
        print('updated: $count');
        expect(count, 1);
        var list = await database.rawQuery('SELECT * FROM Test');
        var expectedList = <Map>[
          {'name': 'updated name', 'id': 1, 'value': 9876, 'num': 456.789},
          {'name': 'another name', 'id': 2, 'value': 12345678, 'num': null}
        ];

        print('list: ${json.encode(list)}');
        print('expected $expectedList');
        expect(list, expectedList);

        count = await database
            .rawDelete('DELETE FROM Test WHERE name = ?', ['another name']);
        print('deleted: $count');
        expect(count, 1);
        list = await database.rawQuery('SELECT * FROM Test');
        expectedList = [
          {'name': 'updated name', 'id': 1, 'value': 9876, 'num': 456.789},
        ];

        print('list: ${json.encode(list)}');
        print('expected $expectedList');
        expect(list, expectedList);
      } finally {
        await database?.close();
      }
    });

    test('Demo clean', () async {
      // Get a location
      var databasesPath = await getDatabasesPath();

      // Make sure the directory exists
      try {
        if (!await Directory(databasesPath).exists()) {
          await Directory(databasesPath).create(recursive: true);
        }
      } catch (_) {}

      var path = join(databasesPath, 'demo.db');

      // Delete the database
      await deleteDatabase(path);

      // open the database
      var database = await openDatabase(path, version: 1,
          onCreate: (Database db, int version) async {
        // When creating the db, create the table
        await db.execute(
            'CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT, value INTEGER, num REAL)');
      });

      // Insert some records in a transaction
      await database.transaction((txn) async {
        var id1 = await txn.rawInsert(
            'INSERT INTO Test(name, value, num) VALUES("some name", 1234, 456.789)');
        print('inserted1: $id1');
        var id2 = await txn.rawInsert(
            'INSERT INTO Test(name, value, num) VALUES(?, ?, ?)',
            ['another name', 12345678, 3.1416]);
        print('inserted2: $id2');
      });

      // Update some record
      var count = await database.rawUpdate(
          'UPDATE Test SET name = ?, value = ? WHERE name = ?',
          ['updated name', '9876', 'some name']);
      print('updated: $count');

      // Get the records
      var list = await database.rawQuery('SELECT * FROM Test');
      var expectedList = [
        {'name': 'updated name', 'id': 1, 'value': 9876, 'num': 456.789},
        {'name': 'another name', 'id': 2, 'value': 12345678, 'num': 3.1416}
      ];
      print(list);
      print(expectedList);
      //assert(const DeepCollectionEquality().equals(list, expectedList));
      expect(list, expectedList);

      // Count the records
      count = Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM Test'));
      expect(count, 2);

      // Delete a record
      count = await database
          .rawDelete('DELETE FROM Test WHERE name = ?', ['another name']);
      expect(count, 1);

      // Close the database
      await database.close();
    });

    test('Open twice', () async {
      // Sqflite.devSetDebugModeOn(true);
      var path = await initDeleteDb('open_twice.db');
      var db = await openDatabase(path);
      Database db2;
      try {
        await db
            .execute('CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT)');
        db2 = await openReadOnlyDatabase(path);

        var count = Sqflite.firstIntValue(
            await db2.rawQuery('SELECT COUNT(*) FROM Test'));
        expect(count, 0);
      } finally {
        await db?.close();
        await db2?.close();
      }
    });

    test('text primary key', () async {
      // Sqflite.devSetDebugModeOn(true);
      var path = await initDeleteDb('text_primary_key.db');
      var db = await openDatabase(path);
      try {
        // This table has no primary key however sqlite generates an hidden row id
        await db.execute('CREATE TABLE Test (name TEXT PRIMARY KEY)');
        var id = await db.insert('Test', {'name': 'test'});
        expect(id, 1);
        id = await db.insert('Test', {'name': 'other'});
        expect(id, 2);
        // row id is not retrieve by default
        var list = await db.query('Test');
        expect(list, [
          {'name': 'test'},
          {'name': 'other'}
        ]);
        list = await db.query('Test', columns: ['name', 'rowid']);
        expect(list, [
          {'name': 'test', 'rowid': 1},
          {'name': 'other', 'rowid': 2}
        ]);
      } finally {
        await db?.close();
      }
    });

    test('without rowid', () async {
      // Sqflite.devSetDebugModeOn(true);
      // this fails on iOS

      Database db;
      try {
        var path = await initDeleteDb('without_rowid.db');
        db = await openDatabase(path);
        // This table has no primary key and we ask sqlite not to generate
        // a rowid
        await db
            .execute('CREATE TABLE Test (name TEXT PRIMARY KEY) WITHOUT ROWID');
        var id = await db.insert('Test', {'name': 'test'});

        expect(id, 0);

        id = await db.insert('Test', {'name': 'other'});
        expect(id, 0);

        // notice the order is based on the primary key
        var list = await db.query('Test');
        expect(list, [
          {'name': 'other'},
          {'name': 'test'}
        ]);
      } finally {
        await db?.close();
      }
    });

    test('Reference query', () async {
      var path = await initDeleteDb('reference_query.db');
      var db = await openDatabase(path);
      try {
        var batch = db.batch();

        batch.execute('CREATE TABLE Other (id INTEGER PRIMARY KEY, name TEXT)');
        batch.execute(
            'CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT, other REFERENCES Other(id))');
        batch.rawInsert('INSERT INTO Other (name) VALUES (?)', ['other 1']);
        batch.rawInsert(
            'INSERT INTO Test (other, name) VALUES (?, ?)', [1, 'item 2']);
        await batch.commit();

        var result = await db.query('Test',
            columns: ['other', 'name'], where: 'other = 1');
        print(result);
        expect(result, [
          {'other': 1, 'name': 'item 2'}
        ]);
        result = await db.query('Test',
            columns: ['other', 'name'], where: 'other = ?', whereArgs: [1]);
        print(result);
        expect(result, [
          {'other': 1, 'name': 'item 2'}
        ]);
      } finally {
        await db.close();
      }
    });
  }
}
