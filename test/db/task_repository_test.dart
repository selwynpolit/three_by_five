import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late TestFixture fixture;
  late String cardId;

  setUp(() async {
    fixture = TestFixture();
    final stackId = await fixture.createStack();
    cardId = await fixture.cards.create(
      stackId: stackId,
      date: DateTime(2024, 6, 1),
    );
  });
  tearDown(() => fixture.close());

  group('TaskRepository — create and watch', () {
    test('created task appears in watchByCard', () async {
      await fixture.tasks.create(cardId: cardId, title: 'First task');
      final tasks = await fixture.tasks.watchByCard(cardId).first;
      expect(tasks, hasLength(1));
      expect(tasks.first.title, 'First task');
    });

    test('defaults: column=now, priority=normal, not completed', () async {
      final id = await fixture.tasks.create(cardId: cardId, title: 'Task');
      final task = await fixture.tasks.getById(id);
      expect(task?.columnName, 'now');
      expect(task?.priority, 'normal');
      expect(task?.isCompleted, isFalse);
      expect(task?.completedAt, isNull);
    });

    test('column and priority are stored as supplied', () async {
      final id = await fixture.tasks.create(
        cardId: cardId,
        title: 'Later high-pri',
        column: 'later',
        priority: 'high',
      );
      final task = await fixture.tasks.getById(id);
      expect(task?.columnName, 'later');
      expect(task?.priority, 'high');
    });
  });

  group('TaskRepository — completion', () {
    test('markComplete sets isCompleted and completedAt', () async {
      final id =
          await fixture.tasks.create(cardId: cardId, title: 'Do it');
      await fixture.tasks.markComplete(id, completed: true);
      final task = await fixture.tasks.getById(id);
      expect(task?.isCompleted, isTrue);
      expect(task?.completedAt, isNotNull);
    });

    test('markComplete false clears completedAt', () async {
      final id =
          await fixture.tasks.create(cardId: cardId, title: 'Do it');
      await fixture.tasks.markComplete(id, completed: true);
      await fixture.tasks.markComplete(id, completed: false);
      final task = await fixture.tasks.getById(id);
      expect(task?.isCompleted, isFalse);
      expect(task?.completedAt, isNull);
    });
  });

  group('TaskRepository — soft delete and restore', () {
    test('deleted task disappears from watchByCard', () async {
      final id =
          await fixture.tasks.create(cardId: cardId, title: 'Temporary');
      await fixture.tasks.delete(id);
      final tasks = await fixture.tasks.watchByCard(cardId).first;
      expect(tasks, isEmpty);
    });

    test('getById returns null for a deleted task', () async {
      final id =
          await fixture.tasks.create(cardId: cardId, title: 'Gone');
      await fixture.tasks.delete(id);
      expect(await fixture.tasks.getById(id), isNull);
    });

    test('restored task reappears in watchByCard', () async {
      final id =
          await fixture.tasks.create(cardId: cardId, title: 'Revived');
      await fixture.tasks.delete(id);
      await fixture.tasks.restore(id);
      final tasks = await fixture.tasks.watchByCard(cardId).first;
      expect(tasks.any((t) => t.id == id), isTrue);
    });
  });

  group('TaskRepository — deleteCompletedForCard', () {
    test('removes only completed tasks', () async {
      final a = await fixture.tasks.create(cardId: cardId, title: 'Active');
      final b = await fixture.tasks.create(cardId: cardId, title: 'Done');
      await fixture.tasks.markComplete(b, completed: true);

      await fixture.tasks.deleteCompletedForCard(cardId);

      final remaining = await fixture.tasks.watchByCard(cardId).first;
      expect(remaining.map((t) => t.id), contains(a));
      expect(remaining.map((t) => t.id), isNot(contains(b)));
    });
  });

  group('TaskRepository — updateDueDate', () {
    test('sets a due date that getById reflects', () async {
      final id = await fixture.tasks.create(cardId: cardId, title: 'Due soon');
      final due = DateTime(2024, 6, 15, 9, 30);
      await fixture.tasks.updateDueDate(id, due);
      final task = await fixture.tasks.getById(id);
      expect(task?.dueDate, due);
    });

    test('reschedules an existing due date to a new day', () async {
      final id = await fixture.tasks.create(cardId: cardId, title: 'Move me');
      await fixture.tasks.updateDueDate(id, DateTime(2024, 6, 10, 14, 0));
      await fixture.tasks.updateDueDate(id, DateTime(2024, 6, 20, 14, 0));
      final task = await fixture.tasks.getById(id);
      expect(task?.dueDate, DateTime(2024, 6, 20, 14, 0));
    });

    test('null clears the due date', () async {
      final id = await fixture.tasks.create(cardId: cardId, title: 'Clear me');
      await fixture.tasks.updateDueDate(id, DateTime(2024, 6, 15));
      await fixture.tasks.updateDueDate(id, null);
      final task = await fixture.tasks.getById(id);
      expect(task?.dueDate, isNull);
    });
  });

  group('TaskRepository — duplicate', () {
    test('duplicate creates a copy with the same title and column', () async {
      final original = await fixture.tasks.create(
        cardId: cardId,
        title: 'Original',
        column: 'later',
        priority: 'high',
      );
      await fixture.tasks.duplicate(original);
      final tasks = await fixture.tasks.watchByCard(cardId).first;
      expect(tasks, hasLength(2));
      final titles = tasks.map((t) => t.title).toList();
      expect(titles.where((t) => t == 'Original'), hasLength(2));
    });
  });
}
