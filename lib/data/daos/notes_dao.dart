import 'package:drift/drift.dart';
import '../database/app_database.dart';

class NotesDao {
  NotesDao(this._db);
  final AppDatabase _db;

  Stream<List<AppNote>> watchByTask(String taskId) =>
      (_db.select(_db.notes)
            ..where((n) => n.taskId.equals(taskId) & n.deletedAt.isNull())
            ..orderBy([(n) => OrderingTerm.asc(n.createdAt)]))
          .watch();

  Future<void> insert(NotesCompanion entry) =>
      _db.into(_db.notes).insert(entry);

  Future<void> update(String id, String body) =>
      (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(
          body: Value(body),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> delete(String id) =>
      (_db.update(_db.notes)..where((n) => n.id.equals(id)))
          .write(NotesCompanion(deletedAt: Value(DateTime.now())));

  Future<void> restore(String id) =>
      (_db.update(_db.notes)..where((n) => n.id.equals(id)))
          .write(const NotesCompanion(deletedAt: Value(null)));
}
