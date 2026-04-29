import '../daos/search_dao.dart';

class SearchRepository {
  SearchRepository(this._dao);
  final SearchDao _dao;

  Future<List<SearchResult>> search(String query) => _dao.search(query);
}
