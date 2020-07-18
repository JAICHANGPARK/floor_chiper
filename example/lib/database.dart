import 'dart:async';
import 'package:example/task2.dart';
import 'package:path/path.dart';
import 'package:example/task.dart';
import 'package:example/task_dao.dart';
import 'package:floor/floor.dart';
import 'package:sqflite_sqlcipher/sqflite.dart'as sqflite;

import 'task2_dao.dart';


part 'database.g.dart';

@Database(version: 1, entities: [Task, Task2])
abstract class FlutterDatabase extends FloorDatabase {
  TaskDao get taskDao;
  Task2Dao get task2Dao;
}
