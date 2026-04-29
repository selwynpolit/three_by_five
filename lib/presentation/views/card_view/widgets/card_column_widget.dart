import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/database/app_database.dart';
import 'task_row_widget.dart';

class CardColumnWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
          // ── Column header ──────────────────────────────────────
          SizedBox(
            height: AppSpacing.columnHeaderHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),

          // ── Tasks ──────────────────────────────────────────────
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
          else
            ...tasks.map(
              (task) => TaskRowWidget(
                task: task,
                isHidden: isHidden,
              ),
            ),

          // ── Add task button (placeholder for Session 4+) ───────
          const SizedBox(height: 4),
          _AddTaskButton(cardId: cardId, column: column),
        ],
      ),
    );
  }
}

// ── Add task placeholder ──────────────────────────────────────────────────────

class _AddTaskButton extends StatefulWidget {
  const _AddTaskButton({required this.cardId, required this.column});
  final String cardId;
  final String column;

  @override
  State<_AddTaskButton> createState() => _AddTaskButtonState();
}

class _AddTaskButtonState extends State<_AddTaskButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _hovered ? 1.0 : 0.0,
        child: Row(
          children: [
            Icon(
              Icons.add,
              size: 13,
              color: AppColors.textTertiary,
            ),
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
    );
  }
}
