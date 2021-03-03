import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqflite;

/// Extend this class to enable database functionality.
abstract class FloorDatabase {
  /// [StreamController] that is responsible for notifying listeners about changes
  /// in specific tables. It acts as an event bus.
  @protected
  StreamController<String> changeListener;

  /// Use this whenever you need direct access to the sqflite database.
  sqflite.DatabaseExecutor database;

  /// Closes the database.
  Future<void> close() async {
    await changeListener?.close();

    final immutableDatabase = database;
    if (immutableDatabase is sqflite.Database && (immutableDatabase?.isOpen ?? false)) {
      await immutableDatabase.close();
    }
  }

  Future<int> version() async {
    final immutableDatabase = database;
    if (immutableDatabase is sqflite.Database && (immutableDatabase?.isOpen ?? false)) {
     return await immutableDatabase.getVersion();
    }else{
      return 0;
    }
  }
}
