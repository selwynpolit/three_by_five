import 'package:drift/native.dart';
import 'package:three_by_five/data/daos/cards_dao.dart';
import 'package:three_by_five/data/daos/notes_dao.dart';
import 'package:three_by_five/data/daos/settings_dao.dart';
import 'package:three_by_five/data/daos/stacks_dao.dart';
import 'package:three_by_five/data/daos/tags_dao.dart';
import 'package:three_by_five/data/daos/tasks_dao.dart';
import 'package:three_by_five/data/database/app_database.dart';
import 'package:three_by_five/data/repositories/card_repository.dart';
import 'package:three_by_five/data/repositories/note_repository.dart';
import 'package:three_by_five/data/repositories/stack_repository.dart';
import 'package:three_by_five/data/repositories/tag_repository.dart';
import 'package:three_by_five/data/repositories/task_repository.dart';

/// Wires up an in-memory AppDatabase with all DAOs and repositories.
/// Create in setUp(), close in tearDown().
class TestFixture {
  final AppDatabase db;
  late final StackRepository stacks;
  late final CardRepository cards;
  late final TaskRepository tasks;
  late final TagRepository tags;
  late final NoteRepository notes;
  late final SettingsDao settings;

  TestFixture._(this.db) {
    stacks = StackRepository(StacksDao(db));
    cards = CardRepository(CardsDao(db));
    tasks = TaskRepository(TasksDao(db));
    tags = TagRepository(TagsDao(db));
    notes = NoteRepository(NotesDao(db));
    settings = SettingsDao(db);
  }

  factory TestFixture() =>
      TestFixture._(AppDatabase.forTesting(NativeDatabase.memory()));

  Future<void> close() => db.close();

  Future<String> createStack({String name = 'Test Stack'}) =>
      stacks.create(name: name, color: 0xFF4CAF50);
}
