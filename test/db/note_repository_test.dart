import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late TestFixture fixture;
  late String taskId;

  setUp(() async {
    fixture = TestFixture();
    final stackId = await fixture.createStack();
    final cardId = await fixture.cards.create(
      stackId: stackId,
      date: DateTime(2024, 6, 1),
    );
    taskId = await fixture.tasks.create(cardId: cardId, title: 'Parent task');
  });
  tearDown(() => fixture.close());

  group('NoteRepository', () {
    test('created note appears in watchByTask', () async {
      await fixture.notes.create(taskId: taskId, body: 'First note');
      final notes = await fixture.notes.watchByTask(taskId).first;
      expect(notes, hasLength(1));
      expect(notes.first.body, 'First note');
    });

    test('updatedAt is null on creation', () async {
      final id = await fixture.notes.create(taskId: taskId, body: 'Fresh');
      final notes = await fixture.notes.watchByTask(taskId).first;
      final note = notes.firstWhere((n) => n.id == id);
      expect(note.updatedAt, isNull);
    });

    test('update changes body and sets updatedAt', () async {
      final id =
          await fixture.notes.create(taskId: taskId, body: 'Original');
      await fixture.notes.update(id, body: 'Revised');
      final notes = await fixture.notes.watchByTask(taskId).first;
      final note = notes.firstWhere((n) => n.id == id);
      expect(note.body, 'Revised');
      expect(note.updatedAt, isNotNull);
    });

    test('deleted note disappears from watchByTask', () async {
      final id = await fixture.notes.create(taskId: taskId, body: 'Gone');
      await fixture.notes.delete(id);
      final notes = await fixture.notes.watchByTask(taskId).first;
      expect(notes.any((n) => n.id == id), isFalse);
    });

    test('restored note reappears in watchByTask', () async {
      final id =
          await fixture.notes.create(taskId: taskId, body: 'Revived');
      await fixture.notes.delete(id);
      await fixture.notes.restore(id);
      final notes = await fixture.notes.watchByTask(taskId).first;
      expect(notes.any((n) => n.id == id), isTrue);
    });

    test('multiple notes for the same task are all returned', () async {
      await fixture.notes.create(taskId: taskId, body: 'Note A');
      await fixture.notes.create(taskId: taskId, body: 'Note B');
      await fixture.notes.create(taskId: taskId, body: 'Note C');
      final notes = await fixture.notes.watchByTask(taskId).first;
      expect(notes, hasLength(3));
    });
  });
}
