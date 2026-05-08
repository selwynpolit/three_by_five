import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/database/app_database.dart';
import '../../../providers/task_providers.dart';
import 'task_row_widget.dart';

class CardColumnWidget extends ConsumerStatefulWidget {
  const CardColumnWidget({
    super.key,
    required this.label,
    required this.tasks,
    required this.cardId,
    required this.column,
    this.isHidden = false,
  });

  final String label;
  final List<AppTask> tasks;
  final String cardId;
  final String column;
  final bool isHidden;

  @override
  ConsumerState<CardColumnWidget> createState() => _CardColumnWidgetState();
}

class _CardColumnWidgetState extends ConsumerState<CardColumnWidget> {
  // Index before which the drop indicator is shown. null = no active drag.
  int? _dropIndex;

  Future<void> _reorder(String draggedId, int insertBefore) async {
    setState(() => _dropIndex = null);
    final tasks = widget.tasks;
    final from = tasks.indexWhere((t) => t.id == draggedId);

    if (from == -1) {
      // Cross-column or cross-card move: preserve insertion position.
      // Build the new order with the dragged task inserted at insertBefore.
      final ids = tasks.map((t) => t.id).toList();
      ids.insert(insertBefore.clamp(0, ids.length), draggedId);
      await ref.read(taskRepositoryProvider).update(
            id: draggedId,
            cardId: widget.cardId,
            column: widget.column,
          );
      await ref.read(taskRepositoryProvider).reorder(ids);
      return;
    }

    var to = insertBefore;
    if (to > from) to -= 1;
    if (from == to) return;

    final reordered = List<AppTask>.from(tasks);
    final item = reordered.removeAt(from);
    reordered.insert(to, item);
    await ref
        .read(taskRepositoryProvider)
        .reorder(reordered.map((t) => t.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.cardPadding,
        right: AppSpacing.cardPadding,
        top: 0,
        bottom: 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Column label ──────────────────────────────────────────
          SizedBox(
            height: AppSpacing.columnHeaderHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),

          // ── Task list (min height = 5 task cells) ─────────────────
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 5 * 26.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tasks.isEmpty)
                  // Empty column — whole area is a drop target.
                  DragTarget<String>(
                    builder: (_, candidates, rejected) => AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: candidates.isNotEmpty
                            ? AppColors.accent.withValues(alpha: 0.07)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        candidates.isNotEmpty ? 'Drop here' : '',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: AppColors.accent,
                            ),
                      ),
                    ),
                    onWillAcceptWithDetails: (_) {
                      setState(() => _dropIndex = 0);
                      return true;
                    },
                    onLeave: (_) => setState(() => _dropIndex = null),
                    onAcceptWithDetails: (d) {
                      _reorder(d.data, 0);
                    },
                  )
                else ...[
                  for (var i = 0; i < tasks.length; i++) ...[
                    _DropZone(
                      active: _dropIndex == i,
                      onWillAccept: (id) {
                        setState(() => _dropIndex = i);
                        return true;
                      },
                      onLeave: (_) {
                        if (_dropIndex == i) setState(() => _dropIndex = null);
                      },
                      onAccept: (id) => _reorder(id, i),
                    ),
                    _DragRow(
                      key: ValueKey(tasks[i].id),
                      task: tasks[i],
                      isHidden: widget.isHidden,
                    ),
                  ],
                  // Final drop zone — append to end.
                  _DropZone(
                    active: _dropIndex == tasks.length,
                    onWillAccept: (id) {
                      setState(() => _dropIndex = tasks.length);
                      return true;
                    },
                    onLeave: (_) {
                      if (_dropIndex == tasks.length) {
                        setState(() => _dropIndex = null);
                      }
                    },
                    onAccept: (id) => _reorder(id, tasks.length),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Drop zone ─────────────────────────────────────────────────────────────────
// 8px tall hit area; shows a 2px accent line when active.

class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.active,
    required this.onWillAccept,
    required this.onLeave,
    required this.onAccept,
  });

  final bool active;
  final bool Function(String id) onWillAccept;
  final void Function(String? id) onLeave;
  final void Function(String id) onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      builder: (_, candidates, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: active ? 22 : 4,
        margin: active
            ? const EdgeInsets.symmetric(vertical: 2)
            : EdgeInsets.zero,
        decoration: active
            ? BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  width: 1,
                ),
              )
            : const BoxDecoration(),
      ),
      onWillAcceptWithDetails: (d) => onWillAccept(d.data),
      onLeave: onLeave,
      onAcceptWithDetails: (d) => onAccept(d.data),
    );
  }
}

// ── Draggable task row ─────────────────────────────────────────────────────────

class _DragRow extends StatefulWidget {
  const _DragRow({
    super.key,
    required this.task,
    required this.isHidden,
  });

  final AppTask task;
  final bool isHidden;

  @override
  State<_DragRow> createState() => _DragRowState();
}

class _DragRowState extends State<_DragRow> {
  bool _hovered = false;

  Widget _buildRow({bool ghost = false}) {
    return Opacity(
      opacity: ghost ? 0.25 : 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle — visible on hover, hidden otherwise.
          AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: (_hovered && !ghost) ? 0.55 : 0.0,
            child: const Padding(
              padding: EdgeInsets.only(top: 5, right: 2),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Icon(
                  Icons.drag_indicator,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          Expanded(
            child: TaskRowWidget(
              task: widget.task,
              isHidden: widget.isHidden,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Draggable<String>(
        data: widget.task.id,
        feedback: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.task.title,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        childWhenDragging: _buildRow(ghost: true),
        child: _buildRow(),
      ),
    );
  }
}

// ── Add task inline ───────────────────────────────────────────────────────────

class _AddTaskButton extends ConsumerStatefulWidget {
  const _AddTaskButton({required this.cardId, required this.column});
  final String cardId;
  final String column;

  @override
  ConsumerState<_AddTaskButton> createState() => _AddTaskButtonState();
}

class _AddTaskButtonState extends ConsumerState<_AddTaskButton> {
  bool _hovered = false;
  bool _isAdding = false;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isAdding) _submit(keepOpen: false);
  }

  void _startAdding() {
    setState(() => _isAdding = true);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _cancel() {
    setState(() {
      _isAdding = false;
      _controller.clear();
    });
  }

  Future<void> _submit({bool keepOpen = false}) async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _cancel();
      return;
    }
    _controller.clear();
    if (keepOpen) {
      // Stay open for rapid consecutive task entry.
      WidgetsBinding.instance
          .addPostFrameCallback((_) { if (mounted) _focusNode.requestFocus(); });
    } else {
      setState(() => _isAdding = false);
    }
    await ref
        .read(taskRepositoryProvider)
        .create(cardId: widget.cardId, title: text, column: widget.column);
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdding) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _cancel,
          const SingleActivator(LogicalKeyboardKey.enter):
              () => _submit(keepOpen: true),
        },
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: Theme.of(context).textTheme.bodySmall,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Task title… (Enter to add, Esc to close)',
            hintStyle: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textDisabled),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            border: InputBorder.none,
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent, width: 1),
            ),
          ),
          textInputAction: TextInputAction.newline,
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _startAdding,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.accent.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _hovered
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : AppColors.cardBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add,
                  size: 12,
                  color: _hovered
                      ? AppColors.accent
                      : AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                'Add task',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _hovered
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
