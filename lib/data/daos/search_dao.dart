import 'package:drift/drift.dart';
import '../database/app_database.dart';

enum SearchSource { task, note }

class SearchResult {
  const SearchResult({
    required this.taskId,
    required this.cardId,
    required this.taskTitle,
    required this.source,
    this.matchedText,
  });

  final String taskId;
  final String cardId;
  final String taskTitle;
  final String? matchedText;
  final SearchSource source;
}

class SearchDao {
  SearchDao(this._db);
  final AppDatabase _db;

  Future<List<SearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final escaped = trimmed.replaceAll('"', '""');
    final ftsQuery = '"$escaped"*';

    final taskRows = await _db.customSelect(
      '''
      SELECT t.id, t.card_id, t.title, t.description
      FROM tasks t
      INNER JOIN tasks_fts ON tasks_fts.rowid = t.rowid
      WHERE tasks_fts MATCH ? AND t.deleted_at IS NULL
      ORDER BY rank
      LIMIT 50
      ''',
      variables: [Variable.withString(ftsQuery)],
      readsFrom: {_db.tasks},
    ).get();

    final noteRows = await _db.customSelect(
      '''
      SELECT n.id, n.task_id, n.body,
             t.title AS task_title, t.card_id
      FROM notes n
      INNER JOIN notes_fts ON notes_fts.rowid = n.rowid
      INNER JOIN tasks t ON t.id = n.task_id
      WHERE notes_fts MATCH ? AND t.deleted_at IS NULL AND n.deleted_at IS NULL
      ORDER BY rank
      LIMIT 50
      ''',
      variables: [Variable.withString(ftsQuery)],
      readsFrom: {_db.notes, _db.tasks},
    ).get();

    return [
      for (final row in taskRows)
        SearchResult(
          taskId: row.read<String>('id'),
          cardId: row.read<String>('card_id'),
          taskTitle: row.read<String>('title'),
          source: SearchSource.task,
          matchedText: row.readNullable<String>('description'),
        ),
      for (final row in noteRows)
        SearchResult(
          taskId: row.read<String>('task_id'),
          cardId: row.read<String>('card_id'),
          taskTitle: row.read<String>('task_title'),
          source: SearchSource.note,
          matchedText: row.read<String>('body'),
        ),
    ];
  }
}
