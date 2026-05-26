import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/app_colors.dart';
import '../../../data/database/app_database.dart';
import '../../providers/card_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/ui_state_providers.dart';

// ── Layout constants ───────────────────────────────────────────────────────────

const _kColWidth = 240.0;
const _kColGap = 14.0;
const _kCardRadius = 8.0;
const _kColRadius = 10.0;
const _kColHeaderH = 44.0;

// ── Root view ─────────────────────────────────────────────────────────────────

class KanbanView extends ConsumerStatefulWidget {
  const KanbanView({super.key});

  @override
  ConsumerState<KanbanView> createState() => _KanbanViewState();
}

class _KanbanViewState extends ConsumerState<KanbanView> {
  bool _hideCompleted = false;
  String _search = '';
  AppTask? _dragging;
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columnsAsync = ref.watch(boardColumnsProvider);
    final tasksAsync = ref.watch(allVisibleTasksProvider);
    final cardsAsync = ref.watch(cardsProvider);

    return Container(
      color: AppColors.appBackground,
      child: Column(
        children: [
          _KanbanHeader(
            hideCompleted: _hideCompleted,
            onToggleCompleted: () =>
                setState(() => _hideCompleted = !_hideCompleted),
            search: _search,
            onSearch: (v) => setState(() => _search = v),
            onAddColumn: _addColumn,
          ),
          Expanded(
            child: columnsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, _) =>
                  Center(child: Text('Error: $e')),
              data: (columns) => _buildBoard(
                columns,
                tasksAsync.valueOrNull ?? [],
                cardsAsync.valueOrNull ?? [],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(
    List<AppBoardColumn> columns,
    List<AppTask> allTasks,
    List<AppCard> cards,
  ) {
    final cardMap = {for (final c in cards) c.id: c};

    // Apply search + hide-completed filter.
    final tasks = allTasks.where((t) {
      if (_hideCompleted && t.isCompleted) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!t.title.toLowerCase().contains(q)) {
          final card = cardMap[t.cardId];
          if (card == null || !(card.projectTitle?.toLowerCase().contains(q) ?? false)) return false;
        }
      }
      return true;
    }).toList();

    // Group tasks by column; unassigned / orphaned IDs → first column.
    final validIds = columns.map((c) => c.id).toSet();
    final Map<String, List<AppTask>> byCol = {
      for (final col in columns) col.id: [],
    };
    for (final t in tasks) {
      final bucket = (t.kanbanStageId != null && validIds.contains(t.kanbanStageId))
          ? t.kanbanStageId!
          : (columns.isNotEmpty ? columns.first.id : null);
      if (bucket != null) byCol[bucket]!.add(t);
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            itemCount: columns.length + 1, // +1 for the add-column ghost
            separatorBuilder: (_, _) => const SizedBox(width: _kColGap),
            itemBuilder: (context, i) {
              if (i == columns.length) return _AddColumnGhost(onAdd: _addColumn);
              final col = columns[i];
              return _KanbanColumn(
                key: ValueKey(col.id),
                column: col,
                tasks: byCol[col.id] ?? [],
                cardMap: cardMap,
                dragging: _dragging,
                onDragStart: (t) => setState(() => _dragging = t),
                onDragEnd: () => setState(() => _dragging = null),
              );
            },
          ),
        ),
        _KanbanScrollbar(controller: _scrollCtrl),
      ],
    );
  }

  Future<void> _addColumn() async {
    final name = await _promptColumnName(context);
    if (name == null || name.isEmpty || !mounted) return;
    await ref.read(boardColumnsRepositoryProvider).create(name);
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _KanbanHeader extends StatelessWidget {
  const _KanbanHeader({
    required this.hideCompleted,
    required this.onToggleCompleted,
    required this.search,
    required this.onSearch,
    required this.onAddColumn,
  });

  final bool hideCompleted;
  final VoidCallback onToggleCompleted;
  final String search;
  final ValueChanged<String> onSearch;
  final VoidCallback onAddColumn;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppColors.appBackground,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            height: 32,
            child: TextField(
              onChanged: onSearch,
              style: const TextStyle(fontSize: 13, color: AppColors.textInverse),
              decoration: InputDecoration(
                hintText: 'Search tasks…',
                hintStyle: TextStyle(
                    fontSize: 13,
                    color: AppColors.textInverse.withValues(alpha: 0.45)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.10),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: AppColors.textInverse.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _ToggleChip(
            label: 'Hide completed',
            active: hideCompleted,
            onTap: onToggleCompleted,
          ),
          const Spacer(),
          _HeaderButton(
            icon: Icons.add,
            label: 'Add column',
            onTap: onAddColumn,
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: active
                  ? Colors.white
                  : AppColors.textInverse.withValues(alpha: 0.7),
              fontWeight: active ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatefulWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 14,
                  color: AppColors.textInverse.withValues(alpha: 0.75)),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textInverse.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Kanban column ─────────────────────────────────────────────────────────────

class _KanbanColumn extends ConsumerStatefulWidget {
  const _KanbanColumn({
    super.key,
    required this.column,
    required this.tasks,
    required this.cardMap,
    required this.dragging,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final AppBoardColumn column;
  final List<AppTask> tasks;
  final Map<String, AppCard> cardMap;
  final AppTask? dragging;
  final ValueChanged<AppTask> onDragStart;
  final VoidCallback onDragEnd;

  @override
  ConsumerState<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends ConsumerState<_KanbanColumn> {
  bool _headerHovered = false;
  bool _editingTitle = false;
  int? _dropIndex;
  late TextEditingController _titleCtrl;
  final _titleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.column.title);
  }

  @override
  void didUpdateWidget(_KanbanColumn old) {
    super.didUpdateWidget(old);
    if (!_editingTitle && old.column.title != widget.column.title) {
      _titleCtrl.text = widget.column.title;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() => _editingTitle = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocus.requestFocus();
      _titleCtrl.selection = TextSelection(
          baseOffset: 0, extentOffset: _titleCtrl.text.length);
    });
  }

  Future<void> _commitEdit() async {
    final text = _titleCtrl.text.trim();
    setState(() => _editingTitle = false);
    if (text.isNotEmpty && text != widget.column.title) {
      final repo = ref.read(boardColumnsRepositoryProvider);
      await repo.rename(widget.column.id, text);
    } else {
      _titleCtrl.text = widget.column.title;
    }
  }

  Future<void> _deleteColumn() async {
    if (!mounted) return;
    final count = widget.tasks.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${widget.column.title}"?'),
        content: Text(count == 0
            ? 'This column is empty.'
            : '$count task${count == 1 ? '' : 's'} will be moved to the first column.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.priorityHigh))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(boardColumnsRepositoryProvider).delete(widget.column.id);
    }
  }

  Future<void> _handleDrop(AppTask task, int insertBefore) async {
    setState(() => _dropIndex = null);
    final repo = ref.read(taskRepositoryProvider); // capture before any await
    final tasks = widget.tasks;
    final from = tasks.indexWhere((t) => t.id == task.id);
    if (from == -1) {
      // Cross-column: update stage.
      await repo.updateKanbanStage(task.id, widget.column.id);
      if (!mounted) return;
      // Auto-complete when dropped into "Done"; auto-uncomplete when dragged out.
      final isDone = widget.column.title.toLowerCase() == 'done';
      if (isDone && !task.isCompleted) {
        await repo.markComplete(task.id, completed: true);
      } else if (!isDone && task.isCompleted) {
        await repo.markComplete(task.id, completed: false);
      }
    } else {
      // Same-column reorder.
      var to = insertBefore;
      if (to > from) to--;
      if (from == to) return;
      final reordered = List<AppTask>.from(tasks)
        ..removeAt(from)
        ..insert(to, tasks[from]);
      await repo.reorder(reordered.map((t) => t.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final incomplete = widget.tasks.where((t) => !t.isCompleted).length;
    final total = widget.tasks.length;
    final lit = _dropIndex != null;

    return SizedBox(
      width: _kColWidth,
      child: Column(
        children: [
          // ── Column header ───────────────────────────────────────────────
          MouseRegion(
            onEnter: (_) => setState(() => _headerHovered = true),
            onExit: (_) => setState(() => _headerHovered = false),
            child: GestureDetector(
              onDoubleTap: _startEdit,
              child: Container(
                height: _kColHeaderH,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: lit ? 0.20 : 0.14),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(_kColRadius)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _editingTitle
                          ? CallbackShortcuts(
                              bindings: {
                                const SingleActivator(
                                        LogicalKeyboardKey.enter):
                                    _commitEdit,
                                const SingleActivator(
                                        LogicalKeyboardKey.escape): () {
                                  _titleCtrl.text = widget.column.title;
                                  setState(() => _editingTitle = false);
                                },
                              },
                              child: TextField(
                                controller: _titleCtrl,
                                focusNode: _titleFocus,
                                onSubmitted: (_) => _commitEdit(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textInverse,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                ),
                              ),
                            )
                          : Text(
                              widget.column.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textInverse,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    const SizedBox(width: 6),
                    if (!_editingTitle) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          incomplete == total
                              ? '$total'
                              : '$incomplete/$total',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textInverse
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: _headerHovered ? 1.0 : 0.0,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            iconSize: 15,
                            color: AppColors.textInverse
                                .withValues(alpha: 0.6),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Delete column',
                            onPressed: _deleteColumn,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Column body ────────────────────────────────────────────────
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              decoration: BoxDecoration(
                color: lit
                    ? Colors.white.withValues(alpha: 0.20)
                    : Colors.white.withValues(alpha: 0.09),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(_kColRadius)),
                border: lit
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5)
                    : null,
              ),
              child: widget.tasks.isEmpty
                  ? _buildEmptyDropTarget()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                      // interleave drop zones: [zone, card, zone, card, …, zone]
                      itemCount: widget.tasks.length * 2 + 1,
                      itemBuilder: (ctx, i) {
                        if (i.isEven) {
                          final pos = i ~/ 2;
                          return _KanbanDropZone(
                            active: _dropIndex == pos,
                            onWillAccept: (task) {
                              final from = widget.tasks
                                  .indexWhere((t) => t.id == task.id);
                              // Skip the zone directly above / below self.
                              if (from != -1 &&
                                  (pos == from || pos == from + 1)) {
                                return false;
                              }
                              setState(() => _dropIndex = pos);
                              return true;
                            },
                            onLeave: (_) {
                              if (_dropIndex == pos) {
                                setState(() => _dropIndex = null);
                              }
                            },
                            onAccept: (task) => _handleDrop(task, pos),
                          );
                        }
                        final task = widget.tasks[(i - 1) ~/ 2];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 0),
                          child: _KanbanTaskCard(
                            task: task,
                            card: widget.cardMap[task.cardId],
                            isDragging: widget.dragging?.id == task.id,
                            onDragStart: () => widget.onDragStart(task),
                            onDragEnd: widget.onDragEnd,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDropTarget() {
    return DragTarget<AppTask>(
      onWillAcceptWithDetails: (_) {
        setState(() => _dropIndex = 0);
        return true;
      },
      onLeave: (_) => setState(() => _dropIndex = null),
      onAcceptWithDetails: (d) => _handleDrop(d.data, 0),
      builder: (_, candidates, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            candidates.isNotEmpty ? 'Drop here' : 'No tasks',
            style: TextStyle(
              fontSize: 12,
              color: candidates.isNotEmpty
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.3),
              fontStyle:
                  candidates.isNotEmpty ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Task card ─────────────────────────────────────────────────────────────────

class _KanbanTaskCard extends ConsumerStatefulWidget {
  const _KanbanTaskCard({
    required this.task,
    required this.card,
    required this.isDragging,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final AppTask task;
  final AppCard? card;
  final bool isDragging;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  ConsumerState<_KanbanTaskCard> createState() => _KanbanTaskCardState();
}

class _KanbanTaskCardState extends ConsumerState<_KanbanTaskCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    return Draggable<AppTask>(
      data: widget.task,
      onDragStarted: widget.onDragStart,
      onDragEnd: (_) => widget.onDragEnd(),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: SizedBox(
          width: _kColWidth - 20,
          child: _buildContent(forFeedback: true),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: content),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => ref
              .read(selectedTaskIdProvider.notifier)
              .select(widget.task.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      )
                    ],
              borderRadius: BorderRadius.circular(_kCardRadius),
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildContent({bool forFeedback = false}) {
    final task = widget.task;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isOverdue = task.dueDate != null &&
        !task.isCompleted &&
        task.dueDate!.isBefore(today);
    final isToday = task.dueDate != null &&
        DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day) ==
            today;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: task.isCompleted
            ? AppColors.cardSurface.withValues(alpha: 0.6)
            : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: task.priority == 'normal'
            ? null
            : Border(
                left: BorderSide(
                  color: task.priority == 'high'
                      ? AppColors.priorityHigh
                      : AppColors.priorityLow,
                  width: 3,
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!forFeedback)
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: 6),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 100),
                    opacity: _hovered ? 0.5 : 0.0,
                    child: const Icon(Icons.drag_indicator,
                        size: 13, color: AppColors.textTertiary),
                  ),
                ),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: task.isCompleted
                        ? AppColors.textCompleted
                        : AppColors.textPrimary,
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textCompleted,
                  ),
                ),
              ),
            ],
          ),
          // Meta row (card name + due date)
          if (widget.card != null || task.dueDate != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (widget.card != null)
                  Expanded(
                    child: Text(
                      widget.card!.projectTitle ?? '—',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (task.dueDate != null) ...[
                  const SizedBox(width: 4),
                  _DueDateChip(
                    date: task.dueDate!,
                    isOverdue: isOverdue,
                    isToday: isToday,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Within-column drop zone ───────────────────────────────────────────────────

class _KanbanDropZone extends StatelessWidget {
  const _KanbanDropZone({
    required this.active,
    required this.onWillAccept,
    required this.onLeave,
    required this.onAccept,
  });

  final bool active;
  final bool Function(AppTask) onWillAccept;
  final void Function(AppTask?) onLeave;
  final void Function(AppTask) onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<AppTask>(
      builder: (_, candidates, _) => SizedBox(
        height: 12,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            height: active ? 2.5 : 0,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(1.5),
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

// ── Due date chip ─────────────────────────────────────────────────────────────

class _DueDateChip extends StatelessWidget {
  const _DueDateChip({
    required this.date,
    required this.isOverdue,
    required this.isToday,
  });

  final DateTime date;
  final bool isOverdue;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (isOverdue) {
      bg = AppColors.overdueBg;
      fg = AppColors.overdueText;
    } else if (isToday) {
      bg = AppColors.dueTodayBg;
      fg = AppColors.dueTodayText;
    } else {
      bg = AppColors.dueFutureBg;
      fg = AppColors.dueFutureText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        intl.DateFormat('MMM d').format(date),
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── Add-column ghost ──────────────────────────────────────────────────────────

class _AddColumnGhost extends StatefulWidget {
  const _AddColumnGhost({required this.onAdd});
  final VoidCallback onAdd;

  @override
  State<_AddColumnGhost> createState() => _AddColumnGhostState();
}

class _AddColumnGhostState extends State<_AddColumnGhost> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kColWidth,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onAdd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(_kColRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: _hovered ? 0.25 : 0.12),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(
                    'Add column',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Custom horizontal scrollbar ───────────────────────────────────────────────

/// A self-contained scrollbar strip that listens to [controller] and renders
/// a visible track + thumb outside the scrollable content area.
class _KanbanScrollbar extends StatefulWidget {
  const _KanbanScrollbar({required this.controller});
  final ScrollController controller;

  @override
  State<_KanbanScrollbar> createState() => _KanbanScrollbarState();
}

class _KanbanScrollbarState extends State<_KanbanScrollbar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: LayoutBuilder(builder: (_, constraints) {
        final trackW = constraints.maxWidth;
        double? thumbLeft, thumbW;

        if (widget.controller.hasClients) {
          final pos = widget.controller.position;
          if (pos.hasContentDimensions && pos.maxScrollExtent > 0) {
            final ratio = pos.viewportDimension / (pos.maxScrollExtent + pos.viewportDimension);
            thumbW = (trackW * ratio).clamp(40.0, trackW - 4);
            final fraction = pos.pixels / pos.maxScrollExtent;
            thumbLeft = fraction * (trackW - thumbW!);
          }
        }

        return SizedBox(
          height: 8,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              if (thumbLeft != null && thumbW != null)
                Positioned(
                  top: 0, bottom: 0,
                  left: thumbLeft,
                  width: thumbW,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<String?> _promptColumnName(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New Column'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Column name'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add')),
      ],
    ),
  );
}

// ── Card-level Kanban dialog ───────────────────────────────────────────────────

/// Opens a kanban board scoped to a single [card]'s tasks.
Future<void> showCardKanbanDialog(BuildContext context, AppCard card) =>
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(32),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          // 3 columns + 2 gaps + side padding
          width: 3 * _kColWidth + 2 * _kColGap + 40,
          height: 520,
          child: _CardKanbanContent(card: card),
        ),
      ),
    );

class _CardKanbanContent extends ConsumerStatefulWidget {
  const _CardKanbanContent({required this.card});
  final AppCard card;

  @override
  ConsumerState<_CardKanbanContent> createState() =>
      _CardKanbanContentState();
}

class _CardKanbanContentState extends ConsumerState<_CardKanbanContent> {
  bool _hideCompleted = false;
  AppTask? _dragging;
  final _scrollCtrl = ScrollController();
  static final _dateFmt = intl.DateFormat('EEE d MMM');

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columnsAsync = ref.watch(boardColumnsProvider);
    final tasksAsync =
        ref.watch(tasksForCardProvider(widget.card.id));

    return Column(
      children: [
        _buildDialogHeader(context),
        Expanded(
          child: Container(
            color: AppColors.appBackground,
            child: columnsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (columns) => tasksAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (tasks) => _buildBoard(columns, tasks),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogHeader(BuildContext context) {
    final card = widget.card;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _dateFmt.format(card.date),
                  style: GoogleFonts.caveat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.1,
                  ),
                ),
                if (card.projectTitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    card.projectTitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          _ToggleChip(
            label: 'Hide completed',
            active: _hideCompleted,
            onTap: () =>
                setState(() => _hideCompleted = !_hideCompleted),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.textTertiary,
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(
      List<AppBoardColumn> columns, List<AppTask> tasks) {
    final cardMap = <String, AppCard>{widget.card.id: widget.card};

    final filtered = tasks.where((t) {
      if (_hideCompleted && t.isCompleted) return false;
      return true;
    }).toList();

    final validIds = columns.map((c) => c.id).toSet();
    final Map<String, List<AppTask>> byCol = {
      for (final col in columns) col.id: [],
    };
    for (final t in filtered) {
      final bucket = (t.kanbanStageId != null &&
              validIds.contains(t.kanbanStageId))
          ? t.kanbanStageId!
          : (columns.isNotEmpty ? columns.first.id : null);
      if (bucket != null) byCol[bucket]!.add(t);
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: columns.length,
            separatorBuilder: (_, _) => const SizedBox(width: _kColGap),
            itemBuilder: (context, i) {
              final col = columns[i];
              return _KanbanColumn(
                key: ValueKey(col.id),
                column: col,
                tasks: byCol[col.id] ?? [],
                cardMap: cardMap,
                dragging: _dragging,
                onDragStart: (t) => setState(() => _dragging = t),
                onDragEnd: () => setState(() => _dragging = null),
              );
            },
          ),
        ),
        _KanbanScrollbar(controller: _scrollCtrl),
      ],
    );
  }

}
