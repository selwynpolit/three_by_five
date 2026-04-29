import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/daos/search_dao.dart';
import '../../data/repositories/search_repository.dart';
import 'database_provider.dart';

part 'search_providers.g.dart';

@Riverpod(keepAlive: true)
SearchRepository searchRepository(SearchRepositoryRef ref) =>
    SearchRepository(SearchDao(ref.watch(appDatabaseProvider)));

/// The current search query string.
@Riverpod(keepAlive: true)
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';

  void set(String query) => state = query;
  void clear() => state = '';
}

/// Search results, re-computed whenever the query changes.
/// Returns empty list for blank queries without hitting the DB.
@riverpod
Future<List<SearchResult>> searchResults(SearchResultsRef ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  return ref.watch(searchRepositoryProvider).search(query);
}
