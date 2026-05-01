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

  Future<void> markComplete(String id, {required bool completed}) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          isCompleted: Value(completed),
          updatedAt: Value(DateTime.now()),
        ),
      );

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
}
