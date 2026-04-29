import 'undo_action.dart';

/// Holds the single most-recent reversible action.
/// Callers call [record] after performing an action, then [consume] + pattern-match to undo it.
class UndoManager {
  UndoAction? _last;

  void record(UndoAction action) => _last = action;

  /// Returns and clears the stored action, or null if nothing to undo.
  UndoAction? consume() {
    final action = _last;
    _last = null;
    return action;
  }

  bool get canUndo => _last != null;
}
