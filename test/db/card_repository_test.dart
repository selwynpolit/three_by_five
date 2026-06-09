import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late TestFixture fixture;
  late String stackId;

  setUp(() async {
    fixture = TestFixture();
    stackId = await fixture.createStack();
  });
  tearDown(() => fixture.close());

  group('CardRepository — CRUD', () {
    test('create returns a non-empty ID', () async {
      final id = await fixture.cards.create(
        stackId: stackId,
        date: DateTime(2024, 6, 1),
        projectTitle: 'Alpha project',
      );
      expect(id, isNotEmpty);
    });

    test('getById returns the created card', () async {
      final id = await fixture.cards.create(
        stackId: stackId,
        date: DateTime(2024, 6, 1),
        projectTitle: 'My project',
      );
      final card = await fixture.cards.getById(id);
      expect(card, isNotNull);
      expect(card!.projectTitle, 'My project');
      expect(card.stackId, stackId);
    });

    test('getById returns null after soft delete', () async {
      final id = await fixture.cards.create(
        stackId: stackId,
        date: DateTime(2024, 6, 1),
      );
      await fixture.cards.delete(id);
      expect(await fixture.cards.getById(id), isNull);
    });

    test('archive sets status to archived', () async {
      final id = await fixture.cards.create(
        stackId: stackId,
        date: DateTime(2024, 6, 1),
      );
      await fixture.cards.archive(id);
      final card = await fixture.cards.getById(id);
      expect(card?.status, 'archived');
    });

    test('restore resets status to active', () async {
      final id = await fixture.cards.create(
        stackId: stackId,
        date: DateTime(2024, 6, 1),
      );
      await fixture.cards.archive(id);
      await fixture.cards.restore(id);
      final card = await fixture.cards.getById(id);
      expect(card?.status, 'active');
    });

    test('undelete makes a soft-deleted card visible again', () async {
      final id = await fixture.cards.create(
        stackId: stackId,
        date: DateTime(2024, 6, 1),
        projectTitle: 'Undo me',
      );
      await fixture.cards.delete(id);
      expect(await fixture.cards.getById(id), isNull);
      await fixture.cards.undelete(id);
      final card = await fixture.cards.getById(id);
      expect(card, isNotNull);
      expect(card!.projectTitle, 'Undo me');
    });
  });

  group('CardRepository.carryForward', () {
    test('creates a new card in the same stack with the same project title', () async {
      final cardId = await fixture.cards.create(
        stackId: stackId,
        date: DateTime(2024, 1, 1),
        projectTitle: 'Q1 Goals',
      );
      final taskId = await fixture.tasks.create(
        cardId: cardId,
        title: 'Write spec',
      );

      final sourceCard = (await fixture.cards.getById(cardId))!;
      final incomplete = await fixture.tasks.watchByCard(cardId).first;

      final newCardId = await fixture.cards.carryForward(
        sourceCard,
        incomplete,
        taskRepo: fixture.tasks,
        tagRepo: fixture.tags,
      );

      final newCard = await fixture.cards.getById(newCardId);
      expect(newCard, isNotNull);
      expect(newCard!.stackId, stackId);
      expect(newCard.projectTitle, 'Q1 Goals');
      expect(newCardId, isNot(cardId));
      // New card should be dated today (within a few seconds of now)
      expect(newCard.date.difference(DateTime.now()).abs().inSeconds,
          lessThan(5));
    });

    test('copies only incomplete tasks', () async {
      final cardId = await fixture.cards.create(
        stackId: stackId,
        date: DateTime(2024, 1, 1),
      );
      await fixture.tasks.create(cardId: cardId, title: 'Todo');
      final t2 = await fixture.tasks.create(cardId: cardId, title: 'Done');
      await fixture.tasks.markComplete(t2, completed: true);

      final sourceCard = (await fixture.cards.getById(cardId))!;
      final allTasks = await fixture.tasks.watchByCard(cardId).first;
      final incomplete = allTasks.where((t) => !t.isCompleted).toList();

      final newCardId = await fixture.cards.carryForward(
        sourceCard,
        incomplete,
        taskRepo: fixture.tasks,
        tagRepo: fixture.tags,
      );

      final copiedTasks = await fixture.tasks.watchByCard(newCardId).first;
      expect(copiedTasks, hasLength(1));
      expect(copiedTasks.first.title, 'Todo');
    });

    test('preserves column, priority, dueDate, and rrule on copied tasks', () async {
      final cardId = await fixture.cards.create(
        stackId: stackId,
        date: DateTime(2024, 1, 1),
      );
      final due = DateTime(2024, 6, 30);
      await fixture.tasks.create(
        cardId: cardId,
        title: 'Important task',
        column: 'later',
        priority: 'high',
        dueDate: due,
        rrule: 'FREQ=WEEKLY',
      );

      final sourceCard = (await fixture.cards.getById(cardId))!;
      final incomplete = await fixture.tasks.watchByCard(cardId).first;

      final newCardId = await fixture.cards.carryForward(
        sourceCard,
        incomplete,
        taskRepo: fixture.tasks,
        tagRepo: fixture.tags,
      );

      final copied = (await fixture.tasks.watchByCard(newCardId).first).first;
      expect(copied.columnName, 'later');
      expect(copied.priority, 'high');
      expect(copied.dueDate, due);
      expect(copied.rrule, 'FREQ=WEEKLY');
    });

    test('does not copy kanbanStageId', () async {
      final cardId = await fixture.cards.create(
        stackId: stackId,
        date: DateTime(2024, 1, 1),
      );
      await fixture.tasks.create(
        cardId: cardId,
        title: 'In progress',
        kanbanStageId: 'col_in_progress',
      );

      final sourceCard = (await fixture.cards.getById(cardId))!;
      final incomplete = await fixture.tasks.watchByCard(cardId).first;

      final newCardId = await fixture.cards.carryForward(
        sourceCard,
        incomplete,
        taskRepo: fixture.tasks,
        tagRepo: fixture.tags,
      );

      final copied = (await fixture.tasks.watchByCard(newCardId).first).first;
      expect(copied.kanbanStageId, isNull);
    });

    test('copies tags to the new tasks', () async {
      final cardId = await fixture.cards.create(
        stackId: stackId,
        date: DateTime(2024, 1, 1),
      );
      final taskId = await fixture.tasks.create(
        cardId: cardId,
        title: 'Tagged task',
      );
      await fixture.tags.addTagNameToTask(taskId, 'urgent');
      await fixture.tags.addTagNameToTask(taskId, 'q1');

      final sourceCard = (await fixture.cards.getById(cardId))!;
      final incomplete = await fixture.tasks.watchByCard(cardId).first;

      final newCardId = await fixture.cards.carryForward(
        sourceCard,
        incomplete,
        taskRepo: fixture.tasks,
        tagRepo: fixture.tags,
      );

      final copiedTasks = await fixture.tasks.watchByCard(newCardId).first;
      final copiedTags = await fixture.tags
          .watchByTask(copiedTasks.first.id)
          .first;
      final tagNames = copiedTags.map((t) => t.name).toSet();
      expect(tagNames, containsAll(['urgent', 'q1']));
    });
  });
}
