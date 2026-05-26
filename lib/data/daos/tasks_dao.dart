import 'package:drift/drift.dart';
import '../database/app_database.dart';

class TasksDao {
  TasksDao(this._db);
  final AppDatabase _db;

  Stream<List<AppTask>> watchByCard(String cardId) =>
      (_db.select(_db.tasks)
            ..where((t) => t.cardId.equals(cardId) & t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder, nulls: NullsOrder.last),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .watch();

  Stream<List<AppTask>> watchByCardAndColumn(String cardId, String column) =>
      (_db.select(_db.tasks)
            ..where((t) =>
                t.cardId.equals(cardId) &
                t.columnName.equals(column) &
                t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder, nulls: NullsOrder.last),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .watch();

  Future<AppTask?> getById(String id) =>
      (_db.select(_db.tasks)
            ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
          .getSingleOrNull();

  Stream<AppTask?> watchById(String id) =>
      (_db.select(_db.tasks)
            ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
          .watchSingleOrNull();

  Future<void> insert(TasksCompanion entry) =>
      _db.into(_db.tasks).insert(entry);

  Future<void> update(TasksCompanion entry) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(entry.id.value)))
          .write(entry);

  Future<void> softDelete(String id) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> restore(String id) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> markComplete(String id, {required bool completed}) {
    final now = DateTime.now();
    return (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        isCompleted: Value(completed),
        completedAt: completed ? Value(now) : const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateDueDate(String id, DateTime? dueDate) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          dueDate: Value(dueDate),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> updateKanbanStage(String id, String? stageId) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          kanbanStageId: Value(stageId),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Returns the next sort_order value for a new task in [cardId]/[column].
  /// Queries existing tasks so the new task always appears at the bottom.
  Future<int> nextSortOrder(String cardId, String column) async {
    final rows = await (_db.select(_db.tasks)
          ..where((t) =>
              t.cardId.equals(cardId) &
              t.columnName.equals(column) &
              t.deletedAt.isNull()))
        .get();
    if (rows.isEmpty) return 0;
    return rows.map((t) => t.sortOrder ?? -1).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> reorder(List<String> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.tasks)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(TasksCompanion(sortOrder: Value(i)));
      }
    });
  }

  Stream<List<AppTask>> watchDueToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.isCompleted.equals(false) &
              t.dueDate.isBiggerOrEqualValue(start) &
              t.dueDate.isSmallerOrEqualValue(end)))
        .watch();
  }

  Stream<List<AppTask>> watchOverdue() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.isCompleted.equals(false) &
              t.dueDate.isNotNull() &
              t.dueDate.isSmallerThanValue(startOfToday)))
        .watch();
  }

  Stream<List<AppTask>> watchInDateRange(DateTime start, DateTime end) =>
      (_db.select(_db.tasks)
            ..where((t) =>
                t.deletedAt.isNull() &
                t.dueDate.isBiggerOrEqualValue(start) &
                t.dueDate.isSmallerOrEqualValue(end))
            ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
          .watch();

  /// All non-deleted tasks whose card is in [cardIds], ordered by card then
  /// sort_order for flat list display.
  Stream<List<AppTask>> watchTasksForCards(List<String> cardIds) {
    if (cardIds.isEmpty) return Stream.value([]);
    return (_db.select(_db.tasks)
          ..where((t) => t.deletedAt.isNull() & t.cardId.isIn(cardIds))
          ..orderBy([
            (t) => OrderingTerm.asc(t.cardId),
            (t) => OrderingTerm.asc(t.sortOrder, nulls: NullsOrder.last),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch();
  }

  /// Soft-delete all completed tasks on [cardId].
  Future<void> deleteCompletedForCard(String cardId) =>
      (_db.update(_db.tasks)
            ..where((t) =>
                t.cardId.equals(cardId) &
                t.isCompleted.equals(true) &
                t.deletedAt.isNull()))
          .write(TasksCompanion(deletedAt: Value(DateTime.now())));

  /// Soft-delete all completed tasks for cards in [cardIds].
  Future<void> deleteCompletedForCards(List<String> cardIds) async {
    if (cardIds.isEmpty) return;
    await (_db.update(_db.tasks)
          ..where((t) =>
              t.cardId.isIn(cardIds) &
              t.isCompleted.equals(true) &
              t.deletedAt.isNull()))
        .write(TasksCompanion(deletedAt: Value(DateTime.now())));
  }
}
