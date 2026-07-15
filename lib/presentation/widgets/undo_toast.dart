import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/undo/undo_action.dart';
import '../providers/card_providers.dart';
import '../providers/detail_providers.dart';
import '../providers/task_providers.dart';
import '../providers/ui_state_providers.dart';

/// Bumped every time an undo is actually executed, so [UndoToast] can flash a
/// brief "Undone" confirmation regardless of how the undo was triggered (the
/// toast button, ⌘Z, or the Edit-menu item).
final undoConfirmationProvider = StateProvider<int>((ref) => 0);

/// Executes the current pending undo action and clears it.
/// Safe to call from any context that has a [WidgetRef] — the toast button,
/// the ⌘Z menu item, and keyboard handlers all share this logic.
Future<void> executeUndo(WidgetRef ref) async {
  final action = ref.read(lastUndoActionProvider.notifier).consume();
  if (action == null) return;

  final tasks = ref.read(taskRepositoryProvider);
  final cards = ref.read(cardRepositoryProvider);

  switch (action) {
    case TaskCompleted(:final taskId, :final wasCompleted):
      await tasks.markComplete(taskId, completed: wasCompleted);
    case TaskDeleted(:final taskId):
      await tasks.restore(taskId);
    case TaskRescheduled(:final taskId, :final previousDueDate):
      await tasks.updateDueDate(taskId, previousDueDate);
    case CardHidden(:final cardId):
      await cards.unhide(cardId);
    case CardSnoozed(:final cardId):
      await cards.unhide(cardId);
    case CardArchived(:final cardId):
      await cards.restore(cardId);
    case CardDeleted(:final cardId):
      await cards.undelete(cardId);
    case NoteDeleted(:final noteId):
      await ref.read(noteRepositoryProvider).restore(noteId);
  }

  // Signal that an undo completed so the UI can confirm it on screen.
  ref.read(undoConfirmationProvider.notifier).state++;
}

class UndoToast extends ConsumerStatefulWidget {
  const UndoToast({super.key});

  @override
  ConsumerState<UndoToast> createState() => _UndoToastState();
}

class _UndoToastState extends ConsumerState<UndoToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _dismissTimer;
  UndoAction? _action;

  /// Non-null while a post-undo confirmation is showing (mutually exclusive
  /// with [_action]).
  String? _confirmation;

  static const _kDuration = Duration(seconds: 4);
  static const _kConfirmationDuration = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _show(UndoAction action) {
    _dismissTimer?.cancel();
    setState(() {
      _action = action;
      _confirmation = null;
    });
    _ctrl.forward(from: 0);
    _dismissTimer = Timer(_kDuration, _dismiss);
  }

  /// Briefly shows an "Undone" confirmation after any undo executes.
  void _showConfirmation() {
    _dismissTimer?.cancel();
    setState(() {
      _action = null;
      _confirmation = 'Undone';
    });
    _ctrl.forward(from: 0);
    _dismissTimer = Timer(_kConfirmationDuration, _dismiss);
  }

  void _dismiss() {
    _ctrl.reverse().then((_) {
      // Don't clear lastUndoActionProvider — ⌘Z must still work after the
      // toast slides out. The action is only consumed when the user undoes.
      if (mounted) {
        setState(() {
          _action = null;
          _confirmation = null;
        });
      }
    });
  }

  Future<void> _undo() async {
    _dismissTimer?.cancel();
    await _ctrl.reverse();
    if (!mounted) return;
    setState(() => _action = null);
    await executeUndo(ref);
  }

  static String _label(UndoAction a) => switch (a) {
        TaskCompleted(:final wasCompleted) =>
          wasCompleted ? 'Marked incomplete' : 'Task completed',
        TaskDeleted() => 'Task deleted',
        TaskRescheduled() => 'Task rescheduled',
        CardHidden() => 'Card hidden',
        CardSnoozed() => 'Card snoozed',
        CardArchived() => 'Card archived',
        CardDeleted() => 'Card deleted',
        NoteDeleted() => 'Note deleted',
      };

  @override
  Widget build(BuildContext context) {
    ref.listen<UndoAction?>(lastUndoActionProvider, (_, next) {
      if (next != null) _show(next);
    });
    ref.listen<int>(undoConfirmationProvider, (_, _) => _showConfirmation());

    if (_action == null && _confirmation == null) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF2D3142),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: _confirmation != null
                ? _buildConfirmationRow()
                : _buildActionRow(),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _label(_action!),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
        ),
        const SizedBox(width: 18),
        GestureDetector(
          onTap: _undo,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              'Undo',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.accentMuted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: _dismiss,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: const Icon(Icons.close, size: 15, color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline,
            size: 16, color: Colors.white),
        const SizedBox(width: 10),
        Text(
          _confirmation!,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}
