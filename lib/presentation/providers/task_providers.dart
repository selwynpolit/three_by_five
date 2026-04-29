import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/daos/attachments_dao.dart';
import '../../data/daos/board_columns_dao.dart';
import '../../data/daos/notes_dao.dart';
import '../../data/daos/tasks_dao.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import 'database_provider.dart';

part 'task_providers.g.dart';

@Riverpod(keepAlive: true)
TaskRepository taskRepository(TaskRepositoryRef ref) =>
    TaskRepository(TasksDao(ref.watch(appDatabaseProvider)));

@Riverpod(keepAlive: true)
BoardColumnsDao boardColumnsDao(BoardColumnsDaoRef ref) =>
    BoardColumnsDao(ref.watch(appDatabaseProvider));

/// All tasks for a given card, ordered by sort_order then created_at.
@riverpod
Stream<List<AppTask>> tasksForCard(TasksForCardRef ref, String cardId) =>
    ref.watch(taskRepositoryProvider).watchByCard(cardId);

/// Tasks in a specific column (now/later) for a card.
@riverpod
Stream<List<AppTask>> tasksForCardColumn(
  TasksForCardColumnRef ref,
  String cardId,
  String column,
) =>
    ref.watch(taskRepositoryProvider).watchByCardAndColumn(cardId, column);

/// Tasks due today across all cards.
@riverpod
Stream<List<AppTask>> tasksDueToday(TasksDueTodayRef ref) =>
    ref.watch(taskRepositoryProvider).watchDueToday();

/// Overdue incomplete tasks.
@riverpod
Stream<List<AppTask>> overdueTasks(OverdueTasksRef ref) =>
    ref.watch(taskRepositoryProvider).watchOverdue();

/// Tasks with due dates in a calendar date range.
@riverpod
Stream<List<AppTask>> tasksInDateRange(
  TasksInDateRangeRef ref,
  DateTime start,
  DateTime end,
) =>
    ref.watch(taskRepositoryProvider).watchInDateRange(start, end);

/// Board columns ordered by sort_order.
@riverpod
Stream<List<AppBoardColumn>> boardColumns(BoardColumnsRef ref) =>
    ref.watch(boardColumnsDaoProvider).watchAll();

/// Live stream for a single task (used by the detail panel).
@riverpod
Stream<AppTask?> taskById(TaskByIdRef ref, String id) =>
    TasksDao(ref.watch(appDatabaseProvider)).watchById(id);

/// Notes for a task, oldest first.
@riverpod
Stream<List<AppNote>> notesForTask(NotesForTaskRef ref, String taskId) =>
    NotesDao(ref.watch(appDatabaseProvider)).watchByTask(taskId);

/// Attachments for a task.
@riverpod
Stream<List<AppAttachment>> attachmentsForTask(
  AttachmentsForTaskRef ref,
  String taskId,
) =>
    AttachmentsDao(ref.watch(appDatabaseProvider)).watchByTask(taskId);
