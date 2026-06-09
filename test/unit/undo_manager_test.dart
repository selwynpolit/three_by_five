import 'package:flutter_test/flutter_test.dart';
import 'package:three_by_five/domain/undo/undo_action.dart';
import 'package:three_by_five/domain/undo/undo_manager.dart';

void main() {
  group('UndoManager', () {
    late UndoManager manager;

    setUp(() => manager = UndoManager());

    test('canUndo is false initially', () {
      expect(manager.canUndo, isFalse);
    });

    test('canUndo is true after record', () {
      manager.record(const TaskDeleted(taskId: 'tid'));
      expect(manager.canUndo, isTrue);
    });

    test('consume returns the recorded action', () {
      const action = TaskDeleted(taskId: 'tid-1');
      manager.record(action);
      expect(manager.consume(), action);
    });

    test('consume clears the action — second call returns null', () {
      manager.record(const NoteDeleted(noteId: 'nid'));
      manager.consume();
      expect(manager.consume(), isNull);
    });

    test('canUndo is false after consume', () {
      manager.record(const CardDeleted(cardId: 'cid'));
      manager.consume();
      expect(manager.canUndo, isFalse);
    });

    test('record overwrites previous action', () {
      manager.record(const TaskDeleted(taskId: 'first'));
      manager.record(const NoteDeleted(noteId: 'second'));
      expect(manager.consume(), isA<NoteDeleted>());
    });
  });

  group('UndoAction subtypes', () {
    test('TaskCompleted preserves wasCompleted flag', () {
      const a = TaskCompleted(taskId: 't1', wasCompleted: false);
      expect(a.taskId, 't1');
      expect(a.wasCompleted, isFalse);
    });

    test('CardArchived preserves previousStatus', () {
      const a = CardArchived(cardId: 'c1', previousStatus: 'active');
      expect(a.previousStatus, 'active');
    });

    test('CardSnoozed and CardHidden carry their cardId', () {
      expect(const CardSnoozed(cardId: 'x').cardId, 'x');
      expect(const CardHidden(cardId: 'y').cardId, 'y');
    });

    test('pattern match covers all subtypes', () {
      final actions = <UndoAction>[
        const TaskCompleted(taskId: 't', wasCompleted: true),
        const TaskDeleted(taskId: 't'),
        const NoteDeleted(noteId: 'n'),
        const CardArchived(cardId: 'c', previousStatus: 'active'),
        const CardDeleted(cardId: 'c'),
        const CardHidden(cardId: 'c'),
        const CardSnoozed(cardId: 'c'),
      ];
      for (final action in actions) {
        // Exhaustive switch must compile — any missing case is a compile error.
        final label = switch (action) {
          TaskCompleted() => 'task-completed',
          TaskDeleted() => 'task-deleted',
          NoteDeleted() => 'note-deleted',
          CardArchived() => 'card-archived',
          CardDeleted() => 'card-deleted',
          CardHidden() => 'card-hidden',
          CardSnoozed() => 'card-snoozed',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
