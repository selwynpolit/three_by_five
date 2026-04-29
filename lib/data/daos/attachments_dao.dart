import 'package:drift/drift.dart';
import '../database/app_database.dart';

class AttachmentsDao {
  AttachmentsDao(this._db);
  final AppDatabase _db;

  Stream<List<AppAttachment>> watchByTask(String taskId) =>
      (_db.select(_db.attachments)
            ..where((a) => a.taskId.equals(taskId) & a.deletedAt.isNull())
            ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
          .watch();

  Future<void> insert(AttachmentsCompanion entry) =>
      _db.into(_db.attachments).insert(entry);

  Future<void> softDelete(String id) =>
      (_db.update(_db.attachments)..where((a) => a.id.equals(id))).write(
        AttachmentsCompanion(deletedAt: Value(DateTime.now())),
      );
}
