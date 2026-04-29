import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/database/app_database.dart';

class TaskMetaWidget extends StatelessWidget {
  const TaskMetaWidget({
    super.key,
    required this.task,
    required this.onPriorityChanged,
    required this.onDueDateChanged,
  });

  final AppTask task;
  final void Function(String priority) onPriorityChanged;
  final void Function(DateTime? date) onDueDateChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PrioritySelector(
          current: task.priority,
          onChanged: onPriorityChanged,
        ),
        _DueDateChip(
          dueDate: task.dueDate,
          onChanged: onDueDateChanged,
          context: context,
        ),
      ],
    );
  }
}

// ── Priority selector ─────────────────────────────────────────────────────────

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({
    required this.current,
    required this.onChanged,
  });

  final String current;
  final void Function(String) onChanged;

  static const _options = [
    ('high', '↑ High', AppColors.priorityHigh),
    ('normal', '— Normal', AppColors.textTertiary),
    ('low', '↓ Low', AppColors.priorityLow),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (value, label, color) in _options) ...[
          _PriorityPill(
            label: label,
            color: color,
            isSelected: current == value,
            onTap: () => onChanged(value),
          ),
          if (value != 'low') const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _PriorityPill extends StatefulWidget {
  const _PriorityPill({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_PriorityPill> createState() => _PriorityPillState();
}

class _PriorityPillState extends State<_PriorityPill> {
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
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.color.withValues(alpha: 0.12)
                : _hovered
                    ? AppColors.divider
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isSelected
                  ? widget.color.withValues(alpha: 0.4)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: widget.isSelected
                      ? widget.color
                      : AppColors.textTertiary,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
          ),
        ),
      ),
    );
  }
}

// ── Due date chip ─────────────────────────────────────────────────────────────

class _DueDateChip extends StatefulWidget {
  const _DueDateChip({
    required this.dueDate,
    required this.onChanged,
    required this.context,
  });

  final DateTime? dueDate;
  final void Function(DateTime? date) onChanged;
  final BuildContext context;

  @override
  State<_DueDateChip> createState() => _DueDateChipState();
}

class _DueDateChipState extends State<_DueDateChip> {
  static final _fmt = DateFormat('d MMM yyyy');
  bool _hovered = false;

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: widget.context,
      initialDate: widget.dueDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.accent,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) widget.onChanged(picked);
  }

  (Color, Color) get _chipColors {
    final d = widget.dueDate;
    if (d == null) return (AppColors.divider, AppColors.textTertiary);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dueDate = DateTime(d.year, d.month, d.day);
    if (dueDate.isBefore(todayDate)) {
      return (AppColors.overdueBg, AppColors.overdueText);
    }
    if (dueDate == todayDate) {
      return (AppColors.dueTodayBg, AppColors.dueTodayText);
    }
    return (AppColors.dueFutureBg, AppColors.dueFutureText);
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _chipColors;
    final label = widget.dueDate != null
        ? _fmt.format(widget.dueDate!)
        : 'No due date';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _pick,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _hovered
                    ? Color.alphaBlend(
                        const Color(0x15000000), bg)
                    : bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 12, color: fg),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: fg, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          if (widget.dueDate != null) ...[
            const SizedBox(width: 2),
            GestureDetector(
              onTap: () => widget.onChanged(null),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Icon(Icons.close,
                    size: 12, color: AppColors.textTertiary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
