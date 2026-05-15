import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../tables/stacks.dart';
import '../tables/board_columns.dart';
import '../tables/cards.dart';
import '../tables/tasks.dart';
import '../tables/notes.dart';
import '../tables/attachments.dart';
import '../tables/tags.dart';
import '../tables/task_tags.dart';
import '../tables/settings.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Stacks,
    BoardColumns,
    Cards,
    Tasks,
    Notes,
    Attachments,
    Tags,
    TaskTags,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedBoardColumns();
          await _createFts5();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(tags, tags.color);
          }
          if (from < 3) {
            // Insert "Pending" between "In Progress" and "Done".
            await customStatement(
                "UPDATE board_columns SET sort_order = 3 WHERE id = 'col_done'");
            await customStatement(
                "INSERT OR IGNORE INTO board_columns (id, title, sort_order) "
                "VALUES ('col_pending', 'Pending', 2)");
          }
        },
      );

  Future<void> _seedBoardColumns() async {
    await batch((b) {
      b.insertAll(boardColumns, [
        BoardColumnsCompanion.insert(
          id: 'col_todo',
          title: 'To Do',
          sortOrder: const Value(0),
        ),
        BoardColumnsCompanion.insert(
          id: 'col_in_progress',
          title: 'In Progress',
          sortOrder: const Value(1),
        ),
        BoardColumnsCompanion.insert(
          id: 'col_pending',
          title: 'Pending',
          sortOrder: const Value(2),
        ),
        BoardColumnsCompanion.insert(
          id: 'col_done',
          title: 'Done',
          sortOrder: const Value(3),
        ),
      ]);
    });
  }

  Future<void> _createFts5() async {
    // External content FTS5 table over tasks (title + description).
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS tasks_fts USING fts5(
        title,
        description,
        content=tasks,
        content_rowid=rowid
      )
    ''');
    // Keep FTS index in sync via triggers.
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS tasks_fts_ai
      AFTER INSERT ON tasks BEGIN
        INSERT INTO tasks_fts(rowid, title, description)
        VALUES (new.rowid, new.title, new.description);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS tasks_fts_ad
      AFTER DELETE ON tasks BEGIN
        INSERT INTO tasks_fts(tasks_fts, rowid, title, description)
        VALUES ('delete', old.rowid, old.title, old.description);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS tasks_fts_au
      AFTER UPDATE ON tasks BEGIN
        INSERT INTO tasks_fts(tasks_fts, rowid, title, description)
        VALUES ('delete', old.rowid, old.title, old.description);
        INSERT INTO tasks_fts(rowid, title, description)
        VALUES (new.rowid, new.title, new.description);
      END
    ''');

    // FTS5 table for notes body text.
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
        body,
        content=notes,
        content_rowid=rowid
      )
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS notes_fts_ai
      AFTER INSERT ON notes BEGIN
        INSERT INTO notes_fts(rowid, body) VALUES (new.rowid, new.body);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS notes_fts_ad
      AFTER DELETE ON notes BEGIN
        INSERT INTO notes_fts(notes_fts, rowid, body)
        VALUES ('delete', old.rowid, old.body);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS notes_fts_au
      AFTER UPDATE ON notes BEGIN
        INSERT INTO notes_fts(notes_fts, rowid, body)
        VALUES ('delete', old.rowid, old.body);
        INSERT INTO notes_fts(rowid, body) VALUES (new.rowid, new.body);
      END
    ''');
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'three_by_five');
}
