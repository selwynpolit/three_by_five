import 'package:drift/drift.dart';
import 'tasks.dart';
import 'tags.dart';

@DataClassName('AppTaskTag')
class TaskTags extends Table {
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}
