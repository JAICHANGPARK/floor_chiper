import 'package:floor/floor.dart';

@entity
class Task2 {
  @PrimaryKey(autoGenerate: true)
  final int id;

  final String message;

  Task2(this.id, this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task2 &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          message == other.message;

  @override
  int get hashCode => id.hashCode ^ message.hashCode;

  @override
  String toString() {
    return 'Task{id: $id, message: $message}';
  }
}
