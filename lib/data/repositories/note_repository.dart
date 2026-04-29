import 'package:uuid/uuid.dart';
import '../daos/notes_dao.dart';
import '../database/app_database.dart';

class NoteRepository {
  NoteRepository(this._dao);
  final NotesDao _dao;
  static const _uuid = Uuid();

  Stream<List<AppNote>> watchByTask(String taskId) =>
      _dao.watchByTask(taskId);

  Future<String> create({
    required String taskId,
    required String body,
  }) async {
    final id = _uuid.v4();
    await _dao.insert(NotesCompanion.insert(
      id: id,
      taskId: taskId,
      body: body,
      createdAt: DateTime.now(),
    ));
    return id;
  }
}
