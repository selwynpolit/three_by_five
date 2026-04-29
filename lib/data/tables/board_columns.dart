import 'package:drift/drift.dart';

@DataClassName('AppBoardColumn')
class BoardColumns extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get color => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
