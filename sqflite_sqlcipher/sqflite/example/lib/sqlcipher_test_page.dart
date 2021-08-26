import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_sqlcipher_example/open_test_page.dart';

import 'package:sqflite/sqflite.dart' as sqflite;

import 'test_page.dart';

/// Cipher test page.
class SqlCipherTestPage extends TestPage {
  /// Cipher test page.
  SqlCipherTestPage() : super('SqlCipher tests') {
    test('Open and query database', () async {
      var path = await initDeleteDb('encrypted.db');

      const password = '1234';

      var db = await openDatabase(
        path,
        password: password,
        version: 1,
        onCreate: (db, version) async {
          var batch = db.batch();

          batch
              .execute('CREATE TABLE Test (id INTEGER PRIMARY KEY, text NAME)');
          await batch.commit();
        },
      );

      try {
        expect(
            await db.rawInsert('INSERT INTO Test (text) VALUES (?)', ['test']),
            1);
        var result = await db.query('Test');
        var expected = [
          {'id': 1, 'text': 'test'}
        ];
        expect(result, expected);

        expect(await isDatabase(path, password: password), isTrue);
      } finally {
        await db.close();
      }
      expect(await isDatabase(path, password: password), isTrue);
    });

    test('Open asset database', () async {
      var databasesPath = await getDatabasesPath();
      var path = join(databasesPath, 'asset_example.db');

      // delete existing if any
      await deleteDatabase(path);

      // Make sure the parent directory exists
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      var data =
          await rootBundle.load(join('assets', 'example_pass_1234.db'));
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      // Write and flush the bytes written
      await File(path).writeAsBytes(bytes, flush: true);

      // open the database
      var db = await openDatabase(path, password: '1234');

      // Our database as a single table with a single element
      List<Map<String, dynamic>> list = await db.rawQuery('SELECT * FROM Test');
      print('list $list');
      expect(list.first['name'], 'simple value');

      await db.close();
    });
    test('Open asset database (SQLCipher 3.x, cipher_migrate on Android)',
        () async {
      var databasesPath = await getDatabasesPath();
      var path = join(databasesPath, 'asset_example_3x.db');

      // delete existing if any
      await deleteDatabase(path);

      // Make sure the parent directory exists
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      var data =
          await rootBundle.load(join('assets', 'sqlcipher-3.0-testkey.db'));
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      // Write and flush the bytes written
      await File(path).writeAsBytes(bytes, flush: true);

      // open the database
      var db = await openDatabase(path, password: 'testkey');

      // Our database as a single table with a single element
      List<Map<String, dynamic>> list = await db.rawQuery('SELECT * FROM t1');
      expect(list.length, greaterThan(0));

      await db.close();
    });

    test('Open an unencrypted database with the package sqflite', () async {
      String path = await initDeleteDb("unencrypted.db");

      Database db = await sqflite.openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          Batch batch = db.batch();

          batch
              .execute("CREATE TABLE Test (id INTEGER PRIMARY KEY, text NAME)");
          await batch.commit();
        },
      );

      try {
        expect(
            await db.rawInsert("INSERT INTO Test (text) VALUES (?)", ['test']),
            1);
        var result = await db.query("Test");
        List expected = [
          {'id': 1, 'text': 'test'}
        ];
        expect(result, expected);
      } finally {
        await db.close();
      }
    });
  }
}
