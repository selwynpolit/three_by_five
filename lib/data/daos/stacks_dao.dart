import 'package:drift/drift.dart';
import '../database/app_database.dart';

class StacksDao {
  StacksDao(this._db);
  final AppDatabase _db;

  Stream<List<AppStack>> watchAll() =>
      (_db.select(_db.stacks)
            ..where((s) => s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .watch();

  Future<AppStack?> getById(String id) =>
      (_db.select(_db.stacks)
            ..where((s) => s.id.equals(id) & s.deletedAt.isNull()))
          .getSingleOrNull();

  Future<void> insert(StacksCompanion entry) =>
      _db.into(_db.stacks).insert(entry);

  Future<void> update(StacksCompanion entry) =>
      (_db.update(_db.stacks)..where((s) => s.id.equals(entry.id.value)))
          .write(entry);

  Future<void> softDelete(String id) =>
      (_db.update(_db.stacks)..where((s) => s.id.equals(id)))
          .write(StacksCompanion(deletedAt: Value(DateTime.now())));

  Future<void> reorder(List<String> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.stacks)
              ..where((s) => s.id.equals(orderedIds[i])))
            .write(StacksCompanion(sortOrder: Value(i)));
      }
    });
  }
}
