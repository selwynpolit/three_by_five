import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../daos/cards_dao.dart';
import '../database/app_database.dart';

class CardRepository {
  CardRepository(this._dao);
  final CardsDao _dao;
  static const _uuid = Uuid();

  Stream<List<AppCard>> watchByStack(
    String stackId, {
    bool showHidden = false,
  }) =>
      _dao.watchByStack(stackId, showHidden: showHidden);

  Stream<List<AppCard>> watchAll({bool showHidden = false}) =>
      _dao.watchAll(showHidden: showHidden);

  Stream<List<AppCard>> watchArchived({String? stackId}) =>
      _dao.watchArchived(stackId: stackId);

  Future<AppCard?> getById(String id) => _dao.getById(id);

  Future<String> create({
    required String stackId,
    required DateTime date,
    String? projectTitle,
    String status = 'active',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _dao.insert(CardsCompanion.insert(
      id: id,
      stackId: stackId,
      date: date,
      projectTitle: Value(projectTitle),
      status: Value(status),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  Future<void> update({
    required String id,
    String? projectTitle,
    DateTime? date,
  }) =>
      _dao.update(CardsCompanion(
        id: Value(id),
        projectTitle:
            projectTitle != null ? Value(projectTitle) : const Value.absent(),
        date: date != null ? Value(date) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> delete(String id) => _dao.softDelete(id);

  Future<void> archive(String id) => _dao.archive(id);

  Future<void> restore(String id) => _dao.restore(id);

  Future<void> hideIndefinitely(String id) => _dao.hideIndefinitely(id);

  Future<void> snoozeUntil(String id, DateTime date) =>
      _dao.snoozeUntil(id, date);

  Future<void> unhide(String id) => _dao.unhide(id);

  Future<void> moveToStack(String id, String stackId) =>
      _dao.moveToStack(id, stackId);

  Future<void> makeBoard(String id) => _dao.setStatus(id, 'expanded');

  Future<void> unboard(String id) => _dao.setStatus(id, 'active');

  Future<List<AppCard>> getActiveByStack(String stackId) =>
      _dao.getActiveByStack(stackId);

  Future<void> moveAllActiveToStack(String fromStackId, String toStackId) =>
      _dao.moveAllActiveToStack(fromStackId, toStackId);

  Future<void> deleteAllByStack(String stackId) =>
      _dao.deleteAllByStack(stackId);
}
