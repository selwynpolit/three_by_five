import 'package:drift/drift.dart';
import 'cards.dart';
import 'board_columns.dart';

@DataClassName('AppTask')
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get cardId => text().references(Cards, #id)();

  /// now | later — which column on the index card this task lives in.
  TextColumn get columnName => text().withDefault(const Constant('now'))();

  TextColumn get title => text()();

  /// Quill Delta JSON. Null = no description yet.
  TextColumn get description => text().nullable()();

  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get dueDate => dateTime().nullable()();

  /// RFC 5545 RRULE string. Null = no recurrence.
  TextColumn get rrule => text().nullable()();

  /// Phase 2: reminder notification timestamp.
  DateTimeColumn get reminderAt => dateTime().nullable()();

  /// high | normal | low
  TextColumn get priority =>
      text().withDefault(const Constant('normal'))();

  /// Which board column this task belongs to when the parent card is expanded.
  TextColumn get kanbanStageId =>
      text().nullable().references(BoardColumns, #id)();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  /// Set when isCompleted becomes true; cleared when the task is uncompleted.
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
