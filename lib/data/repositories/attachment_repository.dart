import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../daos/attachments_dao.dart';
import '../database/app_database.dart';

class AttachmentRepository {
  AttachmentRepository(this._dao);
  final AttachmentsDao _dao;
  static const _uuid = Uuid();

  Stream<List<AppAttachment>> watchByTask(String taskId) =>
      _dao.watchByTask(taskId);

  Future<String> addImage({
    required String taskId,
    required String filePath,
  }) async {
    final id = _uuid.v4();
    await _dao.insert(AttachmentsCompanion.insert(
      id: id,
      taskId: taskId,
      type: 'image',
      filePath: Value(filePath),
      createdAt: DateTime.now(),
    ));
    return id;
  }

  Future<String> addLink({
    required String taskId,
    required String url,
    String? title,
    String? faviconUrl,
  }) async {
    final id = _uuid.v4();
    await _dao.insert(AttachmentsCompanion.insert(
      id: id,
      taskId: taskId,
      type: 'link',
      url: Value(url),
      linkTitle: Value(title),
      faviconUrl: Value(faviconUrl),
      createdAt: DateTime.now(),
    ));
    return id;
  }

  Future<String> addEmailClip({
    required String taskId,
    String? subject,
    String? sender,
    String? bodySnippet,
    String? sourceClient,
    DateTime? originalDate,
  }) async {
    final id = _uuid.v4();
    await _dao.insert(AttachmentsCompanion.insert(
      id: id,
      taskId: taskId,
      type: 'emailClip',
      emailSubject: Value(subject),
      emailSender: Value(sender),
      emailBodySnippet: Value(bodySnippet),
      emailSourceClient: Value(sourceClient),
      emailOriginalDate: Value(originalDate),
      createdAt: DateTime.now(),
    ));
    return id;
  }

  Future<void> delete(String id) => _dao.softDelete(id);
}
