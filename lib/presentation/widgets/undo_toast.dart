import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/undo/undo_action.dart';
import '../providers/card_providers.dart';
import '../providers/task_providers.dart';
import '../providers/ui_state_providers.dart';

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

  static const _kDuration = Duration(seconds: 4);

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
    setState(() => _action = action);
    _ctrl.forward(from: 0);
    _dismissTimer = Timer(_kDuration, _dismiss);
  }

  void _dismiss() {
    _ctrl.reverse().then((_) {
      if (mounted) {
        ref.read(lastUndoActionProvider.notifier).clear();
        setState(() => _action = null);
      }
    });
  }

  Future<void> _undo() async {
    _dismissTimer?.cancel();
    final action = ref.read(lastUndoActionProvider.notifier).consume();
    await _ctrl.reverse();
    if (!mounted || action == null) return;
    setState(() => _action = null);

    final tasks = ref.read(taskRepositoryProvider);
    final cards = ref.read(cardRepositoryProvider);

    switch (action) {
      case TaskCompleted(:final taskId, :final wasCompleted):
        await tasks.markComplete(taskId, completed: wasCompleted);
      case TaskDeleted(:final taskId):
        await tasks.restore(taskId);
      case CardHidden(:final cardId):
        await cards.unhide(cardId);
      case CardSnoozed(:final cardId):
        await cards.unhide(cardId);
      case CardArchived(:final cardId):
        await cards.restore(cardId);
      case CardDeleted(:final cardId):
        await cards.restore(cardId);
    }
  }

  static String _label(UndoAction a) => switch (a) {
        TaskCompleted(:final wasCompleted) =>
          wasCompleted ? 'Marked incomplete' : 'Task completed',
        TaskDeleted() => 'Task deleted',
        CardHidden() => 'Card hidden',
        CardSnoozed() => 'Card snoozed',
        CardArchived() => 'Card archived',
        CardDeleted() => 'Card deleted',
      };

  @override
  Widget build(BuildContext context) {
    ref.listen<UndoAction?>(lastUndoActionProvider, (_, next) {
      if (next != null) _show(next);
    });

    if (_action == null) return const SizedBox.shrink();

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
            child: Row(
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
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                    child: const Icon(Icons.close,
                        size: 15, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
