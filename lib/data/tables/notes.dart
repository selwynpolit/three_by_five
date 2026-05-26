import 'package:drift/drift.dart';
import 'tasks.dart';

@DataClassName('AppNote')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
