import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/app_colors.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/enums/app_view.dart';
import '../../providers/card_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/ui_state_providers.dart';
import '../../widgets/zoom_indicator.dart';
import '../../widgets/zoomed_view_area.dart';

// ── Today dashboard ───────────────────────────────────────────────────────────

class TodayView extends ConsumerStatefulWidget {
  const TodayView({super.key});

  @override
  ConsumerState<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends ConsumerState<TodayView> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overdue = ref.watch(overdueTasksProvider).valueOrNull ?? [];
    final today = ref.watch(tasksDueTodayProvider).valueOrNull ?? [];

    // Upcoming: tomorrow through 7 days out (exclude today, exclude completed).
    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day + 1);
    final weekEnd =
        DateTime(now.year, now.month, now.day + 8, 23, 59, 59, 999);
    final upcoming = (ref
                .watch(tasksInDateRangeProvider(tomorrow, weekEnd))
                .valueOrNull ??
            [])
        .where((t) => !t.isCompleted)
        .toList();

    final cardMap = <String, AppCard>{
      for (final c
          in ref.watch(allCardsIncludingHiddenProvider).valueOrNull ?? [])
        c.id: c,
    };

    final allClear = overdue.isEmpty && today.isEmpty && upcoming.isEmpty;

    return Container(
      color: AppColors.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(),
          Expanded(
            child: ZoomedViewArea(
              view: AppView.todayView,
              child: Builder(builder: (ctx) {
                final scale = CardZoomData.of(ctx);
                return Scrollbar(
                  controller: _scrollCtrl,
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    padding: EdgeInsets.fromLTRB(
                        40 * scale, 28 * scale, 40 * scale, 48 * scale),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 660 * scale),
                        child: allClear
                            ? _AllClearState()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (overdue.isNotEmpty) ...[
                                    _Section(
                                      title: 'Overdue',
                                      accent: AppColors.priorityHigh,
                                      tasks: overdue,
                                      cardMap: cardMap,
                                    ),
                                    const SizedBox(height: 28),
                                  ],
                                  _Section(
                                    title: 'Today',
                                    accent: AppColors.dueTodayText,
                                    tasks: today,
                                    cardMap: cardMap,
                                    emptyMessage: 'Nothing else due today.',
                                  ),
                                  if (upcoming.isNotEmpty) ...[
                                    const SizedBox(height: 28),
                                    _Section(
                                      title: 'Upcoming',
                                      subtitle: 'next 7 days',
                                      accent: AppColors.accent,
                                      tasks: upcoming,
                                      cardMap: cardMap,
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  static final _dayFmt = intl.DateFormat('EEEE');
  static final _dateFmt = intl.DateFormat('d MMMM yyyy');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 22, 40, 18),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dayFmt.format(now),
            style: GoogleFonts.caveat(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          Text(
            _dateFmt.format(now),
            style: const TextStyle(
                fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ── All clear ─────────────────────────────────────────────────────────────────

class _AllClearState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 48, color: AppColors.textDisabled),
          const SizedBox(height: 16),
          Text(
            'All clear!',
            style: GoogleFonts.caveat(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nothing overdue or due today.',
            style: TextStyle(
                fontSize: 14, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ── Task section ──────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.accent,
    required this.tasks,
    required this.cardMap,
    this.subtitle,
    this.emptyMessage,
  });

  final String title;
  final String? subtitle;
  final Color accent;
  final List<AppTask> tasks;
  final Map<String, AppCard> cardMap;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 15,
              decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.3),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 6),
              Text(subtitle!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary)),
            ],
            const Spacer(),
            if (tasks.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(
                      fontSize: 11,
                      color: accent,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Empty state
        if (tasks.isEmpty && emptyMessage != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Text(
              emptyMessage!,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic),
            ),
          )
        else if (tasks.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.cardBorder, width: 0.5),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0E000000),
                    blurRadius: 8,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < tasks.length; i++) ...[
                  _TaskRow(
                    task: tasks[i],
                    card: cardMap[tasks[i].cardId],
                    accent: accent,
                  ),
                  if (i < tasks.length - 1)
                    const Divider(
                        height: 1, indent: 46, endIndent: 14),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ── Task row ──────────────────────────────────────────────────────────────────

class _TaskRow extends ConsumerStatefulWidget {
  const _TaskRow({
    required this.task,
    required this.card,
    required this.accent,
  });
  final AppTask task;
  final AppCard? card;
  final Color accent;

  @override
  ConsumerState<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<_TaskRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final card = widget.card;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () =>
            ref.read(selectedTaskIdProvider.notifier).select(task.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color: _hovered
              ? AppColors.sidebarHover.withValues(alpha: 0.6)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: () => ref
                    .read(taskRepositoryProvider)
                    .markComplete(task.id,
                        completed: !task.isCompleted),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.isCompleted
                          ? widget.accent.withValues(alpha: 0.15)
                          : Colors.transparent,
                      border: Border.all(
                        color: task.isCompleted
                            ? widget.accent
                            : AppColors.textDisabled,
                        width: 1.5,
                      ),
                    ),
                    child: task.isCompleted
                        ? Icon(Icons.check,
                            size: 10, color: widget.accent)
                        : null,
                  ),
                ),
              ),
              // Title + card name
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
                    if (card != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        card.projectTitle ??
                            intl.DateFormat('d MMM').format(card.date),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              // Due date
              if (task.dueDate != null) _DueChip(task.dueDate!),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip(this.date);
  final DateTime date;
  static final _fmt = intl.DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final isOverdue = day.isBefore(today);
    final isToday = day == today;

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
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        isToday ? 'Today' : _fmt.format(date),
        style: TextStyle(
            fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}
