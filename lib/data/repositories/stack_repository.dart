import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../daos/stacks_dao.dart';
import '../database/app_database.dart';

class StackRepository {
  StackRepository(this._dao);
  final StacksDao _dao;
  static const _uuid = Uuid();

  Stream<List<AppStack>> watchAll() => _dao.watchAll();

  Future<AppStack?> getById(String id) => _dao.getById(id);

  Future<String> create({
    required String name,
    required int color,
    String? icon,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    await _dao.insert(StacksCompanion.insert(
      id: id,
      name: name,
      color: color,
      icon: Value(icon),
      sortOrder: Value(sortOrder),
      createdAt: DateTime.now(),
    ));
    return id;
  }

  Future<void> rename(String id, String name) => _dao.update(
        StacksCompanion(id: Value(id), name: Value(name)),
      );

  Future<void> setColor(String id, int color) => _dao.update(
        StacksCompanion(id: Value(id), color: Value(color)),
      );

  Future<void> setIcon(String id, String? icon) => _dao.update(
        StacksCompanion(id: Value(id), icon: Value(icon)),
      );

  Future<void> delete(String id) => _dao.softDelete(id);

  Future<void> reorder(List<String> orderedIds) => _dao.reorder(orderedIds);
}
