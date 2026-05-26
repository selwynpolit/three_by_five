/// Sealed hierarchy of reversible actions.
/// The UndoManager holds the last action; callers pattern-match to perform the inverse.
sealed class UndoAction {
  const UndoAction();
}

// ── Task actions ──────────────────────────────────────────────────────────────

final class TaskCompleted extends UndoAction {
  const TaskCompleted({required this.taskId, required this.wasCompleted});
  final String taskId;

  /// The state to restore (i.e. what it was BEFORE the toggle).
  final bool wasCompleted;
}

final class TaskDeleted extends UndoAction {
  const TaskDeleted({required this.taskId});
  final String taskId;
}

// ── Note actions ──────────────────────────────────────────────────────────────

final class NoteDeleted extends UndoAction {
  const NoteDeleted({required this.noteId});
  final String noteId;
}

// ── Card actions ──────────────────────────────────────────────────────────────

final class CardArchived extends UndoAction {
  const CardArchived({required this.cardId, required this.previousStatus});
  final String cardId;

  /// Status to restore (typically 'active').
  final String previousStatus;
}

final class CardDeleted extends UndoAction {
  const CardDeleted({required this.cardId});
  final String cardId;
}

final class CardHidden extends UndoAction {
  const CardHidden({required this.cardId});
  final String cardId;
}

final class CardSnoozed extends UndoAction {
  const CardSnoozed({required this.cardId});
  final String cardId;
}
