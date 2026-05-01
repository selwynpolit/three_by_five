import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../daos/tasks_dao.dart';
import '../database/app_database.dart';

class TaskRepository {
  TaskRepository(this._dao);
  final TasksDao _dao;
  static const _uuid = Uuid();

  Stream<List<AppTask>> watchByCard(String cardId) =>
      _dao.watchByCard(cardId);

  Stream<List<AppTask>> watchByCardAndColumn(String cardId, String column) =>
      _dao.watchByCardAndColumn(cardId, column);

  Stream<List<AppTask>> watchDueToday() => _dao.watchDueToday();

  Stream<List<AppTask>> watchOverdue() => _dao.watchOverdue();

  Stream<List<AppTask>> watchInDateRange(DateTime start, DateTime end) =>
      _dao.watchInDateRange(start, end);

  Future<AppTask?> getById(String id) => _dao.getById(id);

  Future<String> create({
    required String cardId,
    required String title,
    String column = 'now',
    String priority = 'normal',
    String? description,
    DateTime? dueDate,
    String? rrule,
    String? kanbanStageId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _dao.insert(TasksCompanion.insert(
      id: id,
      cardId: cardId,
      title: title,
      columnName: Value(column),
      priority: Value(priority),
      description: Value(description),
      dueDate: Value(dueDate),
      rrule: Value(rrule),
      kanbanStageId: Value(kanbanStageId),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  Future<void> update({
    required String id,
    String? title,
    String? description,
    String? column,
    String? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? rrule,
    bool clearRrule = false,
    String? kanbanStageId,
    bool clearKanbanStage = false,
  }) =>
      _dao.update(TasksCompanion(
        id: Value(id),
        title: title != null ? Value(title) : const Value.absent(),
        description:
            description != null ? Value(description) : const Value.absent(),
        columnName: column != null ? Value(column) : const Value.absent(),
        priority: priority != null ? Value(priority) : const Value.absent(),
        dueDate: clearDueDate
            ? const Value(null)
            : dueDate != null
                ? Value(dueDate)
                : const Value.absent(),
        rrule: clearRrule
            ? const Value(null)
            : rrule != null
                ? Value(rrule)
                : const Value.absent(),
        kanbanStageId: clearKanbanStage
            ? const Value(null)
            : kanbanStageId != null
                ? Value(kanbanStageId)
                : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> markComplete(String id, {required bool completed}) =>
      _dao.markComplete(id, completed: completed);

  Future<void> delete(String id) => _dao.softDelete(id);

  Future<void> restore(String id) => _dao.restore(id);

  Future<void> updateDueDate(String id, DateTime? dueDate) =>
      _dao.updateDueDate(id, dueDate);

  Future<void> updateKanbanStage(String id, String? stageId) =>
      _dao.updateKanbanStage(id, stageId);

  Future<void> reorder(List<String> orderedIds) => _dao.reorder(orderedIds);

  Future<String> duplicate(String taskId) async {
    final src = await getById(taskId);
    if (src == null) return '';
    return create(
      cardId: src.cardId,
      title: src.title,
      column: src.columnName,
      priority: src.priority,
      description: src.description,
      dueDate: src.dueDate,
    );
  }
}
