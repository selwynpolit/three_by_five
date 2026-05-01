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

  void _reorder(String draggedId, int insertBefore) {
    final tasks = widget.tasks;
    final from = tasks.indexWhere((t) => t.id == draggedId);
    if (from == -1) return; // dragged from a different column — ignore

    var to = insertBefore;
    if (to > from) to -= 1; // account for the removed item
    if (from == to) return; // no actual movement

    final reordered = List<AppTask>.from(tasks);
    final item = reordered.removeAt(from);
    reordered.insert(to, item);
    ref
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
        top: 6,
        bottom: AppSpacing.sm,
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

          // ── Task list ─────────────────────────────────────────────
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Nothing here',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textDisabled,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            )
          else ...[
            for (var i = 0; i < tasks.length; i++) ...[
              _DropZone(
                active: _dropIndex == i,
                onWillAccept: (id) {
                  if (!tasks.any((t) => t.id == id)) return false;
                  setState(() => _dropIndex = i);
                  return true;
                },
                onLeave: (_) {
                  if (_dropIndex == i) setState(() => _dropIndex = null);
                },
                onAccept: (id) {
                  _reorder(id, i);
                  setState(() => _dropIndex = null);
                },
              ),
              _DragRow(
                key: ValueKey(tasks[i].id),
                task: tasks[i],
                isHidden: widget.isHidden,
              ),
            ],
            // Final drop zone — append to end of list.
            _DropZone(
              active: _dropIndex == tasks.length,
              onWillAccept: (id) {
                if (!tasks.any((t) => t.id == id)) return false;
                setState(() => _dropIndex = tasks.length);
                return true;
              },
              onLeave: (_) {
                if (_dropIndex == tasks.length) {
                  setState(() => _dropIndex = null);
                }
              },
              onAccept: (id) {
                _reorder(id, tasks.length);
                setState(() => _dropIndex = null);
              },
            ),
          ],

          // ── Add task ──────────────────────────────────────────────
          const SizedBox(height: 4),
          _AddTaskButton(cardId: widget.cardId, column: widget.column),
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
      builder: (_, candidates, rejected) => SizedBox(
        height: 8,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            height: active ? 2 : 0,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
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
    if (!_focusNode.hasFocus && _isAdding) _submit();
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

  Future<void> _submit() async {
    final text = _controller.text.trim();
    _cancel();
    if (text.isNotEmpty) {
      await ref
          .read(taskRepositoryProvider)
          .create(cardId: widget.cardId, title: text, column: widget.column);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdding) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _cancel,
        },
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: Theme.of(context).textTheme.bodySmall,
          decoration: InputDecoration(
            hintText: 'Task title…',
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
          onSubmitted: (_) => _submit(),
          textInputAction: TextInputAction.done,
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _startAdding,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: _hovered ? 1.0 : 0.35,
          child: Row(
            children: [
              Icon(Icons.add, size: 13, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                'Add task',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
