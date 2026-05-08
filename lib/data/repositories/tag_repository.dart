import 'package:uuid/uuid.dart';
import '../daos/tags_dao.dart';
import '../database/app_database.dart';

class TagRepository {
  TagRepository(this._dao);
  final TagsDao _dao;
  static const _uuid = Uuid();

  Stream<List<AppTag>> watchAll() => _dao.watchAll();

  Stream<List<AppTag>> watchByTask(String taskId) =>
      _dao.watchByTask(taskId);

  /// Returns an existing tag by name, creating it if it doesn't exist.
  /// Safe under concurrent calls: insertOrIgnore absorbs the unique constraint.
  Future<AppTag> getOrCreate(String name) async {
    final normalized = name.trim().toLowerCase();
    await _dao.insertTag(TagsCompanion.insert(
      id: _uuid.v4(),
      name: normalized,
      createdAt: DateTime.now(),
    ));
    return (await _dao.getByName(normalized))!;
  }

  Future<void> addToTask(String taskId, String tagId) =>
      _dao.addToTask(taskId, tagId);

  Future<void> removeFromTask(String taskId, String tagId) =>
      _dao.removeFromTask(taskId, tagId);

  Future<void> removeAllFromTask(String taskId) =>
      _dao.removeAllFromTask(taskId);

  /// Convenience: add tag by name, creating it if needed.
  Future<void> addTagNameToTask(String taskId, String tagName) async {
    final tag = await getOrCreate(tagName);
    await addToTask(taskId, tag.id);
  }

  Future<void> updateTagColor(String id, int? color) =>
      _dao.updateColor(id, color);
}
