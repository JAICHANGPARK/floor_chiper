import 'dart:async';
import 'package:floor/floor.dart';
import 'package:sqflite_sqlcipher/sqflite.dart'as sqflite;
import 'package:path/path.dart';

import 'task.dart';
import 'task2.dart';
import 'task2_dao.dart';
import 'task_dao.dart';

part 'database.g.dart';

@Database(version: 1, entities: [Task, Task2])
abstract class FlutterDatabase extends FloorDatabase {
  TaskDao get taskDao;
  Task2Dao get task2Dao;
}
