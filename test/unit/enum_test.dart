import 'package:flutter_test/flutter_test.dart';
import 'package:three_by_five/domain/enums/card_status.dart';
import 'package:three_by_five/domain/enums/task_column.dart';
import 'package:three_by_five/domain/enums/task_priority.dart';

void main() {
  group('TaskPriority', () {
    test('fromString round-trips all values', () {
      for (final v in TaskPriority.values) {
        expect(TaskPriority.fromString(v.name), v);
      }
    });

    test('fromString throws on unknown value', () {
      expect(() => TaskPriority.fromString('urgent'), throwsArgumentError);
    });
  });

  group('TaskColumn', () {
    test('fromString round-trips all values', () {
      for (final v in TaskColumn.values) {
        expect(TaskColumn.fromString(v.name), v);
      }
    });

    test('"now" and "later" are the only values', () {
      expect(TaskColumn.values, hasLength(2));
      expect(TaskColumn.fromString('now'), TaskColumn.now);
      expect(TaskColumn.fromString('later'), TaskColumn.later);
    });

    test('fromString throws on unknown value', () {
      expect(() => TaskColumn.fromString('soon'), throwsArgumentError);
    });
  });

  group('CardStatus', () {
    test('fromString round-trips all values', () {
      for (final v in CardStatus.values) {
        expect(CardStatus.fromString(v.name), v);
      }
    });

    test('all three statuses are present', () {
      expect(CardStatus.fromString('active'), CardStatus.active);
      expect(CardStatus.fromString('archived'), CardStatus.archived);
      expect(CardStatus.fromString('expanded'), CardStatus.expanded);
    });

    test('fromString throws on unknown value', () {
      expect(() => CardStatus.fromString('deleted'), throwsArgumentError);
    });
  });
}
