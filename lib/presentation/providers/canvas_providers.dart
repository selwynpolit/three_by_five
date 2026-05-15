import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stack_providers.dart';

enum CardLayoutMode { grid, scattered, canvas, taskList }

/// Columns in the task list grid — also used as sort keys.
enum TaskListColumn { task, card, cardDate, dueDate, priority, column, tag, stage }

/// Current sort for the task list grid.
/// When [column] is null the list is in its natural (database) order.
class TaskSortConfig {
  const TaskSortConfig(this.column, {this.ascending = true});
  const TaskSortConfig.unsorted() : column = null, ascending = true;

  final TaskListColumn? column;
  final bool ascending;

  bool get isSorted => column != null;

  /// Cycles: new-column → asc  |  same asc → desc  |  same desc → unsorted.
  TaskSortConfig withToggle(TaskListColumn col) {
    if (column != col) return TaskSortConfig(col);
    if (ascending) return TaskSortConfig(col, ascending: false);
    return const TaskSortConfig.unsorted();
  }
}

final taskListSortConfigProvider = StateProvider<TaskSortConfig>(
    (ref) => const TaskSortConfig(TaskListColumn.cardDate, ascending: false));

final taskListSearchProvider = StateProvider<String>((ref) => '');

/// When true the task list shows tasks from hidden/snoozed cards too.
final showHiddenInTaskListProvider = StateProvider<bool>((ref) => false);

final cardLayoutModeProvider =
    StateProvider<CardLayoutMode>((ref) => CardLayoutMode.scattered);

/// Tracks the last card-based layout (grid/scattered/canvas) so the view can
/// be restored when navigating back from kanban or the task-list layout.
final lastCardLayoutModeProvider =
    StateProvider<CardLayoutMode>((ref) => CardLayoutMode.scattered);

final cardCanvasPositionsProvider =
    NotifierProvider<CardCanvasPositionsNotifier, Map<String, Offset>>(
  CardCanvasPositionsNotifier.new,
);

class CardCanvasPositionsNotifier extends Notifier<Map<String, Offset>> {
  @override
  Map<String, Offset> build() => const {};

  void setPosition(String cardId, Offset offset) =>
      state = {...state, cardId: offset};
}

/// Cards whose header has been clicked — shown with an accent selection ring.
final selectedCardIdsProvider =
    NotifierProvider<SelectedCardIdsNotifier, Set<String>>(
  SelectedCardIdsNotifier.new,
);

class SelectedCardIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Replace the selection with exactly this one card.
  void selectOnly(String id) => state = {id};

  /// Add or remove a card without clearing others (⌘-click / Shift-click).
  void toggle(String id) {
    final next = Set<String>.from(state);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
  }

  void clear() => state = const {};
}

/// The stack that should receive new cards from ⌘N / New Card.
/// Returns [activeStackIdProvider] if set, otherwise the first non-hidden stack,
/// otherwise the first stack of any kind.
///
/// This means ⌘N works even when "All Stacks" is selected in the sidebar.
final effectiveCreateStackProvider = Provider<String?>((ref) {
  final active = ref.watch(activeStackIdProvider);
  if (active != null) return active;
  final stacks = ref.watch(stacksProvider);
  final hidden = ref.watch(hiddenStackIdsProvider);
  return stacks.maybeWhen(
    data: (list) {
      if (list.isEmpty) return null;
      final visible = list.where((s) => !hidden.contains(s.id));
      return visible.isNotEmpty ? visible.first.id : list.first.id;
    },
    orElse: () => null,
  );
});

/// Stack IDs whose cards are currently hidden from the card view.
/// Empty = all stacks visible (the default).
final hiddenStackIdsProvider =
    NotifierProvider<HiddenStackIdsNotifier, Set<String>>(
  HiddenStackIdsNotifier.new,
);

class HiddenStackIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String id) {
    final next = Set<String>.from(state);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
  }

  void showAll() => state = const {};

  void hideAll(Iterable<String> ids) => state = Set.from(ids);
}
