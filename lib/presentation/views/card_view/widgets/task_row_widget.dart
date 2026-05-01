import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/database/app_database.dart';
import '../../../providers/tag_providers.dart';
import '../../../providers/task_providers.dart';
import '../../../providers/ui_state_providers.dart';

class TaskRowWidget extends ConsumerStatefulWidget {
  const TaskRowWidget({
    super.key,
    required this.task,
    this.isHidden = false,
  });

  final AppTask task;
  final bool isHidden;

  @override
  ConsumerState<TaskRowWidget> createState() =>
      _TaskRowWidgetState();
}

class _TaskRowWidgetState extends ConsumerState<TaskRowWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkAnim;
  late final Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.task.isCompleted ? 1.0 : 0.0,
    );
    _checkScale = CurvedAnimation(
      parent: _checkAnim,
      curve: Curves.elasticOut,
    );
  }

  @override
  void didUpdateWidget(TaskRowWidget old) {
    super.didUpdateWidget(old);
    if (widget.task.isCompleted != old.task.isCompleted) {
      widget.task.isCompleted
          ? _checkAnim.forward()
          : _checkAnim.reverse();
    }
  }

  @override
  void dispose() {
    _checkAnim.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    await ref.read(taskRepositoryProvider).markComplete(
          widget.task.id,
          completed: !widget.task.isCompleted,
        );
  }

  Future<void> _showContextMenu(
      BuildContext context, Offset globalPos) async {
    final task = widget.task;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          globalPos.dx, globalPos.dy, globalPos.dx + 1, globalPos.dy + 1),
      items: [
        const PopupMenuItem(value: 'open', child: Text('Open')),
        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
        PopupMenuItem(
          value: task.columnName == 'now' ? 'move_later' : 'move_now',
          child: Text(task.columnName == 'now' ? 'Move to Later' : 'Move to Now'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
    if (!context.mounted) return;
    switch (result) {
      case 'open':
        ref.read(selectedTaskIdProvider.notifier).select(task.id);
      case 'duplicate':
        await ref.read(taskRepositoryProvider).duplicate(task.id);
      case 'move_later':
        await ref.read(taskRepositoryProvider).update(id: task.id, column: 'later');
      case 'move_now':
        await ref.read(taskRepositoryProvider).update(id: task.id, column: 'now');
      case 'delete':
        await ref.read(taskRepositoryProvider).delete(task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final tags = ref.watch(tagsForTaskProvider(task.id));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            ref.read(selectedTaskIdProvider.notifier).select(task.id),
        onSecondaryTapDown: (d) =>
            _showContextMenu(context, d.globalPosition),
        child: _buildRow(context, task, tags),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    AppTask task,
    AsyncValue<List<AppTag>> tags,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Priority indicator ─────────────────────────────────
          _PriorityDot(priority: task.priority),
          const SizedBox(width: 4),

          // ── Checkbox ───────────────────────────────────────────
          GestureDetector(
            onTap: _toggle,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0)
                    .animate(_checkScale),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: AppSpacing.checkboxSize,
                  height: AppSpacing.checkboxSize,
                  decoration: BoxDecoration(
                    color: task.isCompleted
                        ? AppColors.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: task.isCompleted
                          ? AppColors.accent
                          : AppColors.cardBorder,
                      width: 1.5,
                    ),
                  ),
                  child: task.isCompleted
                      ? const Icon(
                          Icons.check,
                          size: 12,
                          color: AppColors.textInverse,
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),

          // ── Title + chips ──────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: widget.isHidden
                            ? AppColors.textDisabled
                            : task.isCompleted
                                ? AppColors.textCompleted
                                : AppColors.textPrimary,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor:
                            AppColors.textCompleted,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _ChipRow(task: task, tagsAsync: tags),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Priority dot ──────────────────────────────────────────────────────────────

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      'high' => AppColors.priorityHigh,
      'low' => AppColors.priorityLow,
      _ => Colors.transparent,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Due-date + tag chips ──────────────────────────────────────────────────────

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.task, required this.tagsAsync});

  final AppTask task;
  final AsyncValue<List<AppTag>> tagsAsync;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    // Due date chip
    if (task.dueDate != null) {
      chips.add(_DueDateChip(dueDate: task.dueDate!));
    }

    // Tag chips (first 3 to keep row compact)
    tagsAsync.whenData((tags) {
      for (final tag in tags.take(3)) {
        chips.add(_TagChip(name: tag.name));
      }
    });

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Wrap(spacing: 4, runSpacing: 3, children: chips),
    );
  }
}

class _DueDateChip extends StatelessWidget {
  const _DueDateChip({required this.dueDate});
  final DateTime dueDate;

  static final _fmt = DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    final (bg, fg, label) = due.isBefore(today)
        ? (AppColors.overdueBg, AppColors.overdueText, _fmt.format(dueDate))
        : due == today
            ? (AppColors.dueTodayBg, AppColors.dueTodayText, 'Today')
            : (AppColors.dueFutureBg, AppColors.dueFutureText,
                _fmt.format(dueDate));

    return _Chip(label: label, bg: bg, fg: fg);
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => _Chip(
        label: name,
        bg: AppColors.tagBg,
        fg: AppColors.tagText,
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontSize: 10,
              letterSpacing: 0,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
