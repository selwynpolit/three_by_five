import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/enums/app_view.dart';
import '../../domain/undo/undo_action.dart';

part 'ui_state_providers.g.dart';

/// Which top-level view is currently shown.
@Riverpod(keepAlive: true)
class ActiveView extends _$ActiveView {
  @override
  AppView build() => AppView.cardView;

  void set(AppView view) => state = view;
}

/// The task currently open in the detail panel. Null = panel closed.
@Riverpod(keepAlive: true)
class SelectedTaskId extends _$SelectedTaskId {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

/// The card open in Board view. Null = no board open.
@Riverpod(keepAlive: true)
class ActiveBoardCardId extends _$ActiveBoardCardId {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

/// The last reversible action performed. Non-null = undo toast should be shown.
/// Use [record] after any undoable operation; [consume] to execute the undo and
/// clear state; [clear] to dismiss the toast without undoing.
@Riverpod(keepAlive: true)
class LastUndoAction extends _$LastUndoAction {
  @override
  UndoAction? build() => null;

  void record(UndoAction action) => state = action;

  /// Returns the action and clears it (call this when the user taps Undo).
  UndoAction? consume() {
    final action = state;
    state = null;
    return action;
  }

  void clear() => state = null;
}
