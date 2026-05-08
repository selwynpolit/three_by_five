import 'package:drift/drift.dart';
import '../database/app_database.dart';

class TagsDao {
  TagsDao(this._db);
  final AppDatabase _db;

  Stream<List<AppTag>> watchAll() =>
      (_db.select(_db.tags)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<AppTag?> getByName(String name) =>
      (_db.select(_db.tags)..where((t) => t.name.equals(name)))
          .getSingleOrNull();

  Future<AppTag?> getById(String id) =>
      (_db.select(_db.tags)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Stream<List<AppTag>> watchByTask(String taskId) {
    final query = _db.select(_db.tags).join([
      innerJoin(
        _db.taskTags,
        _db.taskTags.tagId.equalsExp(_db.tags.id),
      ),
    ])
      ..where(_db.taskTags.taskId.equals(taskId));
    return query.map((row) => row.readTable(_db.tags)).watch();
  }

  /// Inserts a tag, silently ignoring the row if the name already exists.
  Future<void> insertTag(TagsCompanion entry) =>
      _db.into(_db.tags).insert(entry, mode: InsertMode.insertOrIgnore);

  Future<void> addToTask(String taskId, String tagId) =>
      _db.into(_db.taskTags).insert(
        TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> removeFromTask(String taskId, String tagId) =>
      (_db.delete(_db.taskTags)
            ..where(
                (tt) => tt.taskId.equals(taskId) & tt.tagId.equals(tagId)))
          .go();

  Future<void> removeAllFromTask(String taskId) =>
      (_db.delete(_db.taskTags)
            ..where((tt) => tt.taskId.equals(taskId)))
          .go();

  Future<void> updateColor(String id, int? color) =>
      (_db.update(_db.tags)..where((t) => t.id.equals(id)))
          .write(TagsCompanion(color: Value(color)));

  Future<void> renameTag(String id, String name) =>
      (_db.update(_db.tags)..where((t) => t.id.equals(id)))
          .write(TagsCompanion(name: Value(name)));

  Future<void> deleteTag(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.taskTags)
            ..where((tt) => tt.tagId.equals(id)))
          .go();
      await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> mergeTagInto(String keepId, String removeId) async {
    final taskTagsList = await (_db.select(_db.taskTags)
          ..where((tt) => tt.tagId.equals(removeId)))
        .get();
    await _db.transaction(() async {
      for (final tt in taskTagsList) {
        await _db.into(_db.taskTags).insert(
          TaskTagsCompanion.insert(taskId: tt.taskId, tagId: keepId),
          mode: InsertMode.insertOrIgnore,
        );
      }
      await (_db.delete(_db.taskTags)
            ..where((tt) => tt.tagId.equals(removeId)))
          .go();
      await (_db.delete(_db.tags)..where((t) => t.id.equals(removeId)))
          .go();
    });
  }
}
