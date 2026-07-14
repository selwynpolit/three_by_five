import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/app_colors.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/enums/app_view.dart';
import '../../../domain/undo/undo_action.dart';
import '../../providers/card_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/ui_state_providers.dart';
import '../../widgets/zoomed_view_area.dart';

// Drag-to-reschedule visuals.
const double _kDragFeedbackWidth = 160;
const double _kDragOverBorderWidth = 2.0;
const Duration _kPulseDuration = Duration(milliseconds: 420);
const double _kPulsePeakOpacity = 0.5;

// ── Calendar view ─────────────────────────────────────────────────────────────

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late DateTime _month;
  late DateTime _selected;

  /// Destination day of the most recent drop, and a sequence counter that
  /// increments on every drop so the target cell re-pulses each time (even
  /// when consecutive drops land on the same day).
  DateTime? _pulseDate;
  int _pulseSeq = 0;

  static final _monthFmt = intl.DateFormat('MMMM yyyy');
  static final _panelFmt = intl.DateFormat('EEE, d MMMM');

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
    _selected = DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(allVisibleTasksProvider);
    final cardsAsync = ref.watch(allCardsIncludingHiddenProvider);

    final tasks = tasksAsync.valueOrNull ?? [];
    final cardMap = <String, AppCard>{
      for (final c in cardsAsync.valueOrNull ?? []) c.id: c,
    };

    // Group incomplete tasks that have a due date by their calendar day.
    final Map<DateTime, List<AppTask>> byDate = {};
    for (final t in tasks) {
      if (t.dueDate == null) continue;
      final d = _dateOnly(t.dueDate!);
      (byDate[d] ??= []).add(t);
    }

    // Sort each day's tasks: high priority first, then by title.
    for (final list in byDate.values) {
      list.sort((a, b) {
        const rank = {'high': 0, 'normal': 1, 'low': 2};
        final pr = (rank[a.priority] ?? 1).compareTo(rank[b.priority] ?? 1);
        return pr != 0 ? pr : a.title.compareTo(b.title);
      });
    }

    final selectedTasks = byDate[_selected] ?? [];

    return Container(
      color: AppColors.canvas,
      child: Column(
        children: [
          _buildNavBar(),
          Expanded(
            child: ZoomedViewArea(
              view: AppView.calendarView,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildGrid(byDate)),
                  _DayPanel(
                    date: _selected,
                    tasks: selectedTasks,
                    cardMap: cardMap,
                    label: _panelFmt.format(_selected),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Navigation bar ──────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          _NavBtn(Icons.chevron_left, onTap: _prevMonth),
          const SizedBox(width: 4),
          Text(
            _monthFmt.format(_month),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          _NavBtn(Icons.chevron_right, onTap: _nextMonth),
          const SizedBox(width: 12),
          _TodayBtn(onTap: _goToday),
          const Spacer(),
          _Legend(color: AppColors.priorityHigh, label: 'High'),
          const SizedBox(width: 16),
          _Legend(color: AppColors.accent, label: 'Normal'),
          const SizedBox(width: 16),
          _Legend(color: AppColors.priorityLow, label: 'Low'),
        ],
      ),
    );
  }

  // ── Month grid ──────────────────────────────────────────────────────────────

  Widget _buildGrid(Map<DateTime, List<AppTask>> byDate) {
    final today = _dateOnly(DateTime.now());
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final startPad = (_month.weekday - 1) % 7; // Mon = 0

    final cells = <DateTime?>[
      ...List<DateTime?>.filled(startPad, null),
      for (var i = 1; i <= daysInMonth; i++)
        DateTime(_month.year, _month.month, i),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final weeks = cells.length ~/ 7;

    return Column(
      children: [
        // Day-name header row
        Row(
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map((n) => Expanded(
                    child: Container(
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.sidebarBg,
                        border: Border(
                          bottom: BorderSide(
                              color: AppColors.divider, width: 0.5),
                          right: BorderSide(
                              color: AppColors.divider, width: 0.5),
                        ),
                      ),
                      child: Text(
                        n,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        // Week rows
        for (var w = 0; w < weeks; w++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: _DayCell(
                      date: cells[w * 7 + d],
                      tasks: cells[w * 7 + d] != null
                          ? (byDate[cells[w * 7 + d]] ?? [])
                          : [],
                      isToday: cells[w * 7 + d] == today,
                      isSelected: cells[w * 7 + d] == _selected,
                      isWeekend: d >= 5,
                      onTap: cells[w * 7 + d] != null
                          ? () => setState(
                              () => _selected = cells[w * 7 + d]!)
                          : null,
                      onTaskDropped: cells[w * 7 + d] != null
                          ? (taskId) =>
                              _reschedule(taskId, cells[w * 7 + d]!)
                          : null,
                      pulse: cells[w * 7 + d] != null &&
                              cells[w * 7 + d] == _pulseDate
                          ? _pulseSeq
                          : 0,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Moves [taskId]'s due date to [day], preserving the original time of day.
  /// No-op when the task already falls on that day. Records an undo action and
  /// pulses the destination cell. The calendar's StreamProvider re-emits, so
  /// the grid updates itself — no explicit invalidation needed.
  Future<void> _reschedule(String taskId, DateTime day) async {
    final repo = ref.read(taskRepositoryProvider);
    final task = await repo.getById(taskId);
    if (task == null || task.dueDate == null) return;
    final old = task.dueDate!;
    if (_dateOnly(old) == day) return; // already on this day
    final newDue =
        DateTime(day.year, day.month, day.day, old.hour, old.minute, old.second);
    await repo.updateDueDate(taskId, newDue);
    ref
        .read(lastUndoActionProvider.notifier)
        .record(TaskRescheduled(taskId: taskId, previousDueDate: old));
    if (!mounted) return;
    setState(() {
      _pulseDate = day;
      _pulseSeq++;
    });
  }

  void _prevMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month + 1));
  void _goToday() {
    final n = DateTime.now();
    setState(() {
      _month = DateTime(n.year, n.month);
      _selected = DateTime(n.year, n.month, n.day);
    });
  }
}

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

// ── Day cell ─────────────────────────────────────────────────────────────────

class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.date,
    required this.tasks,
    required this.isToday,
    required this.isSelected,
    required this.isWeekend,
    required this.onTap,
    required this.onTaskDropped,
    required this.pulse,
  });

  final DateTime? date;
  final List<AppTask> tasks;
  final bool isToday;
  final bool isSelected;
  final bool isWeekend;
  final VoidCallback? onTap;

  /// Called with the dropped task's id when a pill is released on this cell.
  final void Function(String taskId)? onTaskDropped;

  /// Non-zero when this cell is the destination of a just-completed drop; the
  /// value changes on every drop so a fresh pulse fires each time.
  final int pulse;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _dragOver = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: _kPulseDuration);
  }

  @override
  void didUpdateWidget(covariant _DayCell old) {
    super.didUpdateWidget(old);
    if (widget.pulse != 0 && widget.pulse != old.pulse) {
      _pulseCtrl.forward(from: 0).then((_) {
        if (mounted) _pulseCtrl.reverse();
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.date == null) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.sidebarBg,
          border: Border(
            right: BorderSide(color: AppColors.divider, width: 0.5),
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
      );
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) {
        setState(() => _dragOver = true);
        return true;
      },
      onLeave: (_) => setState(() => _dragOver = false),
      onAcceptWithDetails: (d) {
        setState(() => _dragOver = false);
        widget.onTaskDropped?.call(d.data);
      },
      builder: (context, candidate, rejected) => _buildCell(),
    );
  }

  Widget _buildCell() {
    final Color bg;
    if (_dragOver || widget.isSelected) {
      bg = AppColors.accentLight;
    } else if (_hovered) {
      bg = AppColors.sidebarHover;
    } else if (widget.isWeekend) {
      bg = const Color(0xFFF8F5EF);
    } else {
      bg = Colors.white;
    }

    final border = _dragOver
        ? Border.all(color: AppColors.accent, width: _kDragOverBorderWidth)
        : Border(
            left: widget.isSelected
                ? const BorderSide(color: AppColors.accent, width: 2.5)
                : const BorderSide(color: AppColors.divider, width: 0.5),
            bottom: const BorderSide(color: AppColors.divider, width: 0.5),
          );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(color: bg, border: border),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date number with today-circle
                    _DateNumber(
                      day: widget.date!.day,
                      isToday: widget.isToday,
                      isSelected: widget.isSelected,
                    ),
                    const SizedBox(height: 2),
                    // Up to 3 task pills
                    for (final t in widget.tasks.take(3)) _TaskPill(task: t),
                    if (widget.tasks.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          '+${widget.tasks.length - 3}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Settle-pulse overlay when a task lands here.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, _) => _pulseCtrl.value == 0
                        ? const SizedBox.shrink()
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(
                                  alpha: _pulseCtrl.value * _kPulsePeakOpacity),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateNumber extends StatelessWidget {
  const _DateNumber(
      {required this.day, required this.isToday, required this.isSelected});
  final int day;
  final bool isToday;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: isToday
          ? const BoxDecoration(
              color: AppColors.accent, shape: BoxShape.circle)
          : null,
      child: Text(
        '$day',
        style: TextStyle(
          fontSize: 12,
          fontWeight:
              isToday ? FontWeight.w700 : FontWeight.w500,
          color: isToday
              ? Colors.white
              : isSelected
                  ? AppColors.accent
                  : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _TaskPill extends StatelessWidget {
  const _TaskPill({required this.task});
  final AppTask task;

  static final _dueFmt = intl.DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final color = task.priority == 'high'
        ? AppColors.priorityHigh
        : task.priority == 'low'
            ? AppColors.priorityLow
            : AppColors.accent;

    final textStyle = TextStyle(
      fontSize: 10,
      color: task.isCompleted ? color.withValues(alpha: 0.45) : color,
      fontWeight: FontWeight.w500,
      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
      decorationColor: color.withValues(alpha: 0.45),
    );

    final pill = Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: task.isCompleted
            ? color.withValues(alpha: 0.06)
            : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      ),
    );

    // Makes the pill draggable onto another day cell to reschedule it.
    Widget draggable(Widget child) => Draggable<String>(
          data: task.id,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              width: _kDragFeedbackWidth,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                    color: color.withValues(alpha: 0.4), width: 0.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 6),
                ],
              ),
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle.copyWith(decoration: null),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: pill),
          child: child,
        );

    return LayoutBuilder(builder: (context, constraints) {
      final tp = TextPainter(
        text: TextSpan(text: task.title, style: textStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth - 8);

      if (!tp.didExceedMaxLines) return draggable(pill);

      // Build tooltip meta line (priority + due date).
      final parts = <String>[];
      if (task.priority == 'high') parts.add('High priority');
      if (task.priority == 'low') parts.add('Low priority');
      if (task.dueDate != null) parts.add('Due ${_dueFmt.format(task.dueDate!)}');
      final meta = parts.join(' · ');

      return draggable(Tooltip(
        richMessage: TextSpan(
          children: [
            TextSpan(
              text: task.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (meta.isNotEmpty) ...[
              const TextSpan(text: '\n'),
              TextSpan(
                text: meta,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
        decoration: BoxDecoration(
          color: const Color(0xE6232323),
          borderRadius: BorderRadius.circular(6),
        ),
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 500),
        child: pill,
      ));
    });
  }
}

// ── Day panel (right sidebar) ─────────────────────────────────────────────────

class _DayPanel extends ConsumerWidget {
  const _DayPanel({
    required this.date,
    required this.tasks,
    required this.cardMap,
    required this.label,
  });

  final DateTime date;
  final List<AppTask> tasks;
  final Map<String, AppCard> cardMap;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = _dateOnly(DateTime.now());
    final isToday = date == now;
    final isPast = date.isBefore(now);
    final incomplete = tasks.where((t) => !t.isCompleted).length;
    final completed = tasks.length - incomplete;

    return Container(
      width: 276,
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border:
            Border(left: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'Today' : label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isToday ? AppColors.accent : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                if (tasks.isEmpty)
                  Text(
                    isPast ? 'Nothing was due' : 'Nothing due',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                        fontStyle: FontStyle.italic),
                  )
                else
                  Text(
                    '$incomplete open · $completed done',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),
          // Task list
          Expanded(
            child: tasks.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: tasks.length,
                    itemBuilder: (ctx, i) => _PanelTaskTile(
                      task: tasks[i],
                      card: cardMap[tasks[i].cardId],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PanelTaskTile extends ConsumerWidget {
  const _PanelTaskTile({required this.task, required this.card});
  final AppTask task;
  final AppCard? card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = task.priority == 'high'
        ? AppColors.priorityHigh
        : task.priority == 'low'
            ? AppColors.priorityLow
            : AppColors.accent;

    return InkWell(
      onTap: () =>
          ref.read(selectedTaskIdProvider.notifier).select(task.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Priority bar
            Container(
              width: 3,
              height: 30,
              margin: const EdgeInsets.only(right: 10, top: 1),
              decoration: BoxDecoration(
                color: task.isCompleted
                    ? color.withValues(alpha: 0.3)
                    : color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: task.isCompleted
                          ? AppColors.textCompleted
                          : AppColors.textPrimary,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: AppColors.textCompleted,
                    ),
                  ),
                  if (card?.projectTitle != null || card != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      card!.projectTitle ??
                          intl.DateFormat('d MMM').format(card!.date),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _NavBtn extends StatefulWidget {
  const _NavBtn(this.icon, {required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
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
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.sidebarHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon,
              size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _TodayBtn extends StatefulWidget {
  const _TodayBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_TodayBtn> createState() => _TodayBtnState();
}

class _TodayBtnState extends State<_TodayBtn> {
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
          duration: const Duration(milliseconds: 100),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.accentLight : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _hovered
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.cardBorder,
              width: 0.5,
            ),
          ),
          child: const Text(
            'Today',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.accent,
                fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textTertiary)),
      ],
    );
  }
}
