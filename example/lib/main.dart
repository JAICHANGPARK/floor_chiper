import 'dart:io';
import 'dart:typed_data';

import 'package:example/database.dart';
import 'package:example/task.dart';
import 'package:example/task_dao.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqflite;

String kDbName = "flutter_database_ex.db";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = await $FloorFlutterDatabase.databaseBuilder(kDbName, "super").build();
  final dao = database.taskDao;

  runApp(FloorApp(dao));
}

class FloorApp extends StatelessWidget {
  final TaskDao dao;

  const FloorApp(this.dao);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Floor Demo',
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: TasksWidget(
        title: 'Floor Demo',
        dao: dao,
      ),
    );
  }
}

class TasksWidget extends StatefulWidget {
  final String title;
  final TaskDao dao;

  const TasksWidget({
    Key? key,
    required this.title,
    required this.dao,
  }) : super(key: key);

  @override
  State<TasksWidget> createState() => _TasksWidgetState();
}

class _TasksWidgetState extends State<TasksWidget> {
  Future getPermission() async {
    if (await Permission.storage.request().isGranted) {
      // Either the permission was already granted before or the user just granted it.
    }

// You can request multiple permissions at once.
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.storage,
    ].request();

    print(statuses[Permission.storage]);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    getPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              String path = await sqflite.getDatabasesPath();
              path = join(path, kDbName);
              print(path);
              File dbFile = File(path);
              Uint8List dbData = await dbFile.readAsBytes();
              final Directory s = (await getExternalStorageDirectory())!;
              String outPath = s.path;
              print(outPath);
              outPath = join(s.path, kDbName);
              print(outPath);
              File file = File(outPath);
              file = await file.writeAsBytes(dbData);
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            TasksListView(dao: widget.dao),
            TasksTextField(dao: widget.dao),
          ],
        ),
      ),
    );
  }
}

class TasksListView extends StatelessWidget {
  final TaskDao dao;

  const TasksListView({
    Key? key,
    required this.dao,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StreamBuilder<List<Task>>(
        stream: dao.findAllTasksAsStream(),
        builder: (_, snapshot) {
          if (!snapshot.hasData) return Container();

          final tasks = snapshot.requireData;

          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (_, index) {
              return TaskListCell(
                task: tasks[index],
                dao: dao,
              );
            },
          );
        },
      ),
    );
  }
}

class TaskListCell extends StatelessWidget {
  final Task task;
  final TaskDao dao;

  const TaskListCell({
    Key? key,
    required this.task,
    required this.dao,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('${task.hashCode}'),
      background: Container(color: Colors.red),
      direction: DismissDirection.endToStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 16,
        ),
        child: Text(task.message),
      ),
      onDismissed: (_) async {
        await dao.deleteTask(task);

        final scaffoldMessengerState = ScaffoldMessenger.of(context);
        scaffoldMessengerState.hideCurrentSnackBar();
        scaffoldMessengerState.showSnackBar(
          const SnackBar(content: Text('Removed task')),
        );
      },
    );
  }
}

class TasksTextField extends StatelessWidget {
  final TextEditingController _textEditingController;
  final TaskDao dao;

  TasksTextField({
    Key? key,
    required this.dao,
  })  : _textEditingController = TextEditingController(),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black12,
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _textEditingController,
              decoration: const InputDecoration(
                fillColor: Colors.transparent,
                filled: true,
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
                hintText: 'Type task here',
              ),
              onSubmitted: (_) async {
                await _persistMessage();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton(
              child: const Text('Save'),
              onPressed: () async {
                await _persistMessage();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _persistMessage() async {
    final message = _textEditingController.text;
    if (message.trim().isEmpty) {
      _textEditingController.clear();
    } else {
      final task = Task(null, message);
      await dao.insertTask(task);
      _textEditingController.clear();
    }
  }
}
