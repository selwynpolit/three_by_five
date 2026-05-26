import '../daos/board_columns_dao.dart';
import '../database/app_database.dart';

class BoardColumnsRepository {
  BoardColumnsRepository(this._dao);
  final BoardColumnsDao _dao;

  Stream<List<AppBoardColumn>> watchAll() => _dao.watchAll();
  Future<String> create(String title) => _dao.create(title);
  Future<void> rename(String id, String newTitle) => _dao.rename(id, newTitle);
  Future<void> delete(String id) => _dao.delete(id);
  Future<void> reorder(List<String> orderedIds) => _dao.reorder(orderedIds);
}
