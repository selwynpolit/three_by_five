import 'package:drift/drift.dart';

@DataClassName('AppTag')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get color => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
