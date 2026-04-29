import 'package:drift/drift.dart';
import '../database/app_database.dart';

class BoardColumnsDao {
  BoardColumnsDao(this._db);
  final AppDatabase _db;

  Stream<List<AppBoardColumn>> watchAll() =>
      (_db.select(_db.boardColumns)
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .watch();

  Future<List<AppBoardColumn>> getAll() =>
      (_db.select(_db.boardColumns)
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();

  Future<void> rename(String id, String newTitle) =>
      (_db.update(_db.boardColumns)..where((c) => c.id.equals(id)))
          .write(BoardColumnsCompanion(title: Value(newTitle)));

  Future<void> reorder(List<String> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.boardColumns)
              ..where((c) => c.id.equals(orderedIds[i])))
            .write(BoardColumnsCompanion(sortOrder: Value(i)));
      }
    });
  }
}
