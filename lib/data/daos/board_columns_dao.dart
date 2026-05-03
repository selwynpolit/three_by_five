import 'dart:math';

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

  Future<String> create(String title) async {
    final all = await getAll();
    final nextOrder =
        all.isEmpty ? 0 : all.map((c) => c.sortOrder).reduce(max) + 1;
    final id = 'col_${DateTime.now().millisecondsSinceEpoch}';
    await _db.into(_db.boardColumns).insert(BoardColumnsCompanion.insert(
          id: id,
          title: title,
          sortOrder: Value(nextOrder),
        ));
    return id;
  }

  Future<void> delete(String id) async {
    await _db.transaction(() async {
      // Unassign all tasks in this column rather than cascading delete.
      await (_db.update(_db.tasks)
            ..where((t) => t.kanbanStageId.equals(id)))
          .write(const TasksCompanion(kanbanStageId: Value(null)));
      await (_db.delete(_db.boardColumns)..where((c) => c.id.equals(id))).go();
    });
  }
}
