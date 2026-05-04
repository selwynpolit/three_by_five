import 'dart:math' as math;

import 'package:intl/intl.dart' as intl;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/undo/undo_action.dart';
import '../../providers/canvas_providers.dart';
import '../../providers/card_providers.dart';
import '../../providers/stack_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/ui_state_providers.dart';
import 'widgets/index_card_widget.dart';

class CardView extends ConsumerWidget {
  const CardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutMode = ref.watch(cardLayoutModeProvider);
    final cardsAsync = ref.watch(cardsProvider);
    final stacks = ref.watch(stacksProvider);
    final activeStackId = ref.watch(activeStackIdProvider);
    final hiddenStackIds = ref.watch(hiddenStackIdsProvider);
    // Show stack pill on each card only when multiple stacks are visible.
    final showStackPill = hiddenStackIds.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardViewHeader(layoutMode: layoutMode, activeStackId: activeStackId),
        Expanded(
          child: Builder(builder: (context) {
            // valueOrNull prevents flicker during periodic resurfacing refresh.
            final cards = cardsAsync.valueOrNull;
            if (cards == null) return const SizedBox.shrink();
            if (cardsAsync.hasError) {
              return Center(child: Text('Error: ${cardsAsync.error}'));
            }
            // Task list doesn't depend on cards being visible.
            if (layoutMode == CardLayoutMode.taskList) return const _TaskListView();
            if (cards.isEmpty) return const _EmptyState();
            final stackMap = stacks.maybeWhen(
              data: (list) =>
                  <String, AppStack>{for (final s in list) s.id: s},
              orElse: () => <String, AppStack>{},
            );
            return switch (layoutMode) {
              CardLayoutMode.grid =>
                _GridView(cards: cards, stackMap: stackMap, showStackPill: showStackPill),
              CardLayoutMode.scattered =>
                _ScatteredView(cards: cards, stackMap: stackMap, showStackPill: showStackPill),
              CardLayoutMode.canvas =>
                _CanvasView(cards: cards, stackMap: stackMap, showStackPill: showStackPill),
              CardLayoutMode.taskList =>
                const _TaskListView(),
            };
          }),
        ),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _CardViewHeader extends ConsumerWidget {
  const _CardViewHeader(
      {required this.layoutMode, required this.activeStackId});
  final CardLayoutMode layoutMode;
  final String? activeStackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showHidden = ref.watch(showHiddenCardsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.viewPadding, 14, AppSpacing.viewPadding, 10),
      child: Row(
        children: [
          _LayoutPicker(current: layoutMode),
          const SizedBox(width: 4),
          // Show hidden toggle
          _PickerBtn(
            icon: showHidden
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            tooltip: showHidden ? 'Showing hidden cards' : 'Show hidden cards',
            active: showHidden,
            onTap: () =>
                ref.read(showHiddenCardsProvider.notifier).toggle(),
          ),
          const Spacer(),
          Builder(builder: (context) {
            final createStackId =
                ref.watch(effectiveCreateStackProvider);
            if (createStackId == null) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DeleteCompletedButton(),
                const SizedBox(width: 8),
                _GenerateButton(stackId: createStackId),
                const SizedBox(width: 8),
                _NewCardButton(stackId: createStackId),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Layout mode picker ────────────────────────────────────────────────────────

class _LayoutPicker extends ConsumerWidget {
  const _LayoutPicker({required this.current});
  final CardLayoutMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void set(CardLayoutMode m) {
      ref.read(cardLayoutModeProvider.notifier).state = m;
      if (m != CardLayoutMode.taskList) {
        ref.read(lastCardLayoutModeProvider.notifier).state = m;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PickerBtn(
          icon: Icons.grid_view_rounded,
          tooltip: 'Sorted grid',
          active: current == CardLayoutMode.grid,
          onTap: () => set(CardLayoutMode.grid),
        ),
        const SizedBox(width: 2),
        _PickerBtn(
          icon: Icons.style_outlined,
          tooltip: 'Scattered',
          active: current == CardLayoutMode.scattered,
          onTap: () => set(CardLayoutMode.scattered),
        ),
        const SizedBox(width: 2),
        _PickerBtn(
          icon: Icons.open_with_rounded,
          tooltip: 'Free canvas',
          active: current == CardLayoutMode.canvas,
          onTap: () => set(CardLayoutMode.canvas),
        ),
        const SizedBox(width: 2),
        _PickerBtn(
          icon: Icons.format_list_bulleted_rounded,
          tooltip: 'Task list',
          active: current == CardLayoutMode.taskList,
          onTap: () => set(CardLayoutMode.taskList),
        ),
      ],
    );
  }
}

class _PickerBtn extends StatefulWidget {
  const _PickerBtn({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_PickerBtn> createState() => _PickerBtnState();
}

class _PickerBtnState extends State<_PickerBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: widget.active
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : _hovered
                      ? AppColors.divider
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.active ? AppColors.accent : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── New card button ───────────────────────────────────────────────────────────

class _NewCardButton extends ConsumerStatefulWidget {
  const _NewCardButton({required this.stackId});
  final String stackId;

  @override
  ConsumerState<_NewCardButton> createState() => _NewCardButtonState();
}

class _NewCardButtonState extends ConsumerState<_NewCardButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => ref.read(cardRepositoryProvider).create(
              stackId: widget.stackId,
              date: DateTime.now(),
            ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white
                : Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add,
                  size: 14,
                  color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                'New Card',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grid layout ───────────────────────────────────────────────────────────────

class _GridView extends StatelessWidget {
  const _GridView({required this.cards, required this.stackMap, required this.showStackPill});
  final List<AppCard> cards;
  final Map<String, AppStack> stackMap;
  final bool showStackPill;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.viewPadding, 0,
            AppSpacing.viewPadding, AppSpacing.viewPadding),
        child: Wrap(
          spacing: AppSpacing.cardGap,
          runSpacing: AppSpacing.cardGap,
          children: cards
              .map((c) => IndexCardWidget(
                    card: c,
                    stackColor: _stackColor(c, stackMap),
                    stackName: showStackPill ? stackMap[c.stackId]?.name : null,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ── Scattered layout ──────────────────────────────────────────────────────────

class _ScatteredView extends StatelessWidget {
  const _ScatteredView({required this.cards, required this.stackMap, required this.showStackPill});
  final List<AppCard> cards;
  final Map<String, AppStack> stackMap;
  final bool showStackPill;

  // Deterministic rotation (-3.5° … +3.5°) derived from card ID hash.
  double _angle(String id) =>
      ((id.hashCode % 700) - 350) / 100.0 * (math.pi / 180);

  // 0–19 px top offset for staggered vertical placement.
  double _yOff(String id) => ((id.hashCode >> 8) % 20).toDouble();

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.viewPadding + 12, 4,
            AppSpacing.viewPadding + 12, AppSpacing.viewPadding + 12),
        child: Wrap(
          spacing: 40,
          runSpacing: 44,
          children: cards.map((c) {
            return Padding(
              padding: EdgeInsets.only(top: _yOff(c.id)),
              child: Transform.rotate(
                angle: _angle(c.id),
                child: IndexCardWidget(
                  card: c,
                  stackColor: _stackColor(c, stackMap),
                  stackName: showStackPill ? stackMap[c.stackId]?.name : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Free canvas layout ────────────────────────────────────────────────────────

class _CanvasView extends ConsumerWidget {
  const _CanvasView({required this.cards, required this.stackMap, required this.showStackPill});
  final List<AppCard> cards;
  final Map<String, AppStack> stackMap;
  final bool showStackPill;

  static Offset _defaultPos(int index) {
    const cols = 3;
    const cellW = AppSpacing.cardWidth + 40.0;
    const cellH = 324.0;
    const margin = 40.0;
    return Offset(
      margin + (index % cols) * cellW,
      margin + (index ~/ cols) * cellH,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positions = ref.watch(cardCanvasPositionsProvider);

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(400),
      minScale: 0.35,
      maxScale: 2.0,
      child: SizedBox(
        width: 3200,
        height: 2400,
        child: Stack(
          children: cards.asMap().entries.map((e) {
            final pos = positions[e.value.id] ?? _defaultPos(e.key);
            return _CanvasCard(
              key: ValueKey(e.value.id),
              card: e.value,
              stackColor: _stackColor(e.value, stackMap),
              stackName: showStackPill ? stackMap[e.value.stackId]?.name : null,
              initialOffset: pos,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CanvasCard extends ConsumerStatefulWidget {
  const _CanvasCard({
    super.key,
    required this.card,
    required this.stackColor,
    required this.initialOffset,
    this.stackName,
  });
  final AppCard card;
  final Color stackColor;
  final Offset initialOffset;
  final String? stackName;

  @override
  ConsumerState<_CanvasCard> createState() => _CanvasCardState();
}

class _CanvasCardState extends ConsumerState<_CanvasCard> {
  late Offset _pos;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _pos = widget.initialOffset;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IndexCardWidget(card: widget.card, stackColor: widget.stackColor,
              stackName: widget.stackName),
          // Drag handle covers the top accent strip + header area.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 46,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => setState(() => _dragging = true),
              onPanUpdate: (d) => setState(() => _pos += d.delta),
              onPanEnd: (_) {
                setState(() => _dragging = false);
                ref
                    .read(cardCanvasPositionsProvider.notifier)
                    .setPosition(widget.card.id, _pos);
              },
              child: MouseRegion(
                cursor: _dragging
                    ? SystemMouseCursors.grabbing
                    : SystemMouseCursors.grab,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No cards here yet',
            style: GoogleFonts.caveat(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Press ⌘N or click New Card to create your first card',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ── Generate button (test data) ───────────────────────────────────────────────

class _GenerateButton extends ConsumerStatefulWidget {
  const _GenerateButton({required this.stackId});
  final String stackId;

  @override
  ConsumerState<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends ConsumerState<_GenerateButton> {
  bool _hovered = false;
  bool _busy = false;

  static const _nowTitles = [
    'Review weekly goals',
    'Send project update',
    'Fix blocking bug',
    'Prepare meeting notes',
    'Reply to emails',
  ];
  static const _laterTitles = [
    'Read documentation',
    'Refactor auth module',
    'Write unit tests',
    'Update roadmap',
    'Schedule 1-on-1s',
  ];

  Future<void> _generate() async {
    if (_busy) return;
    setState(() => _busy = true);
    final cardRepo = ref.read(cardRepositoryProvider);
    final taskRepo = ref.read(taskRepositoryProvider);
    final now = DateTime.now();
    for (var c = 0; c < 3; c++) {
      final cardDate = now.subtract(Duration(days: c));
      final cardId = await cardRepo.create(
        stackId: widget.stackId,
        date: cardDate,
      );
      for (var i = 0; i < 5; i++) {
        await taskRepo.create(
          cardId: cardId,
          title: _nowTitles[i],
          column: 'now',
        );
        await taskRepo.create(
          cardId: cardId,
          title: _laterTitles[i],
          column: 'later',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Generate 3 test cards with 5 tasks each',
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: _generate,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5,
                        color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Generate',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Delete-completed button ───────────────────────────────────────────────────

class _DeleteCompletedButton extends ConsumerStatefulWidget {
  const _DeleteCompletedButton();

  @override
  ConsumerState<_DeleteCompletedButton> createState() =>
      _DeleteCompletedButtonState();
}

class _DeleteCompletedButtonState
    extends ConsumerState<_DeleteCompletedButton> {
  bool _hovered = false;

  Future<void> _delete() async {
    final cardIds =
        ref.read(cardsProvider).valueOrNull?.map((c) => c.id).toList() ?? [];
    if (cardIds.isEmpty) return;
    await ref
        .read(taskRepositoryProvider)
        .deleteCompletedForCards(cardIds);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Delete all completed tasks in visible stacks',
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: _delete,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.checklist_rounded,
              size: 16,
              color: _hovered
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Task list view — spreadsheet grid ─────────────────────────────────────────

// Column width constants
const _kCbW = 36.0;    // checkbox
const _kPriW = 24.0;   // priority dot
const _kCardW = 130.0; // card title
const _kDateW = 82.0;  // card date
const _kDueW = 82.0;   // due date
const _kWhereW = 56.0; // now / later
const _kStatusW = 80.0; // hidden status

class _TaskRowData {
  const _TaskRowData({required this.task, this.card});
  final AppTask task;
  final AppCard? card;

  bool get isCardHidden {
    if (card == null) return false;
    if (card!.isHidden) return true;
    final u = card!.hiddenUntil;
    return u != null && u.isAfter(DateTime.now());
  }
}

class _TaskListView extends ConsumerStatefulWidget {
  const _TaskListView();

  @override
  ConsumerState<_TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends ConsumerState<_TaskListView> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => ref.read(taskListSearchProvider.notifier).state =
            _searchCtrl.text);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    Future.microtask(
        () => ref.read(taskListSearchProvider.notifier).state = '');
    super.dispose();
  }

  static const _priVal = {'high': 2, 'normal': 1, 'low': 0};

  List<_TaskRowData> _sorted(List<_TaskRowData> rows, TaskSortConfig cfg) {
    final result = List.of(rows);
    int dir(int v) => cfg.ascending ? v : -v;

    switch (cfg.column) {
      case TaskListColumn.task:
        result.sort((a, b) => dir(a.task.title.compareTo(b.task.title)));
      case TaskListColumn.card:
        result.sort((a, b) => dir((a.card?.projectTitle ?? '')
            .compareTo(b.card?.projectTitle ?? '')));
      case TaskListColumn.cardDate:
        result.sort((a, b) => dir((a.card?.date ?? DateTime(2000))
            .compareTo(b.card?.date ?? DateTime(2000))));
      case TaskListColumn.dueDate:
        result.sort((a, b) {
          final ad = a.task.dueDate, bd = b.task.dueDate;
          if (ad == null && bd == null) return 0;
          if (ad == null) return dir(1);
          if (bd == null) return dir(-1);
          return dir(ad.compareTo(bd));
        });
      case TaskListColumn.priority:
        result.sort((a, b) => dir((_priVal[b.task.priority] ?? 1)
            .compareTo(_priVal[a.task.priority] ?? 1)));
      case TaskListColumn.column:
        result.sort((a, b) =>
            dir(a.task.columnName.compareTo(b.task.columnName)));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(allVisibleTasksProvider);
    final allCardsAsync = ref.watch(allCardsIncludingHiddenProvider);
    final search = ref.watch(taskListSearchProvider);
    final sortCfg = ref.watch(taskListSortConfigProvider);
    final showHidden = ref.watch(showHiddenInTaskListProvider);

    // Build card map from all cards (including hidden ones).
    final cardMap = <String, AppCard>{
      for (final c in allCardsAsync.valueOrNull ?? []) c.id: c,
    };

    final rawTasks = tasksAsync.valueOrNull ?? [];

    // Build row data, optionally filtering hidden-card rows.
    var rows = rawTasks.map((t) => _TaskRowData(task: t, card: cardMap[t.cardId])).toList();
    if (!showHidden) rows = rows.where((r) => !r.isCardHidden).toList();

    // Search filter.
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      rows = rows
          .where((r) => r.task.title.toLowerCase().contains(q) ||
              (r.card?.projectTitle?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    rows = _sorted(rows, sortCfg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Search + toggle bar ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search tasks…',
                    hintStyle: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textDisabled),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: AppColors.textTertiary),
                    suffixIcon: search.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              ref.read(taskListSearchProvider.notifier).state = '';
                            },
                            child: const Icon(Icons.close,
                                size: 16, color: AppColors.textTertiary),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.cardSurface,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppColors.cardBorder, width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppColors.cardBorder, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppColors.accent, width: 1),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Hidden cards toggle
              Tooltip(
                message: showHidden
                    ? 'Hiding tasks from hidden cards'
                    : 'Showing tasks from hidden cards',
                child: GestureDetector(
                  onTap: () => ref
                      .read(showHiddenInTaskListProvider.notifier)
                      .state = !showHidden,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: showHidden
                            ? AppColors.accent.withValues(alpha: 0.12)
                            : AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: showHidden
                              ? AppColors.accent.withValues(alpha: 0.4)
                              : AppColors.cardBorder,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            showHidden
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 14,
                            color: showHidden
                                ? AppColors.accent
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Hidden',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: showHidden
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Grid ─────────────────────────────────────────────────────
        _GridHeader(sort: sortCfg),
        const Divider(height: 1),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    search.isEmpty ? 'No tasks.' : 'No results.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textDisabled,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                )
              : Scrollbar(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (ctx, i) => _GridDataRow(
                      key: ValueKey(rows[i].task.id),
                      rowData: rows[i],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Grid header row ───────────────────────────────────────────────────────────

class _GridHeader extends ConsumerWidget {
  const _GridHeader({required this.sort});
  final TaskSortConfig sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void onSort(TaskListColumn col) => ref
        .read(taskListSortConfigProvider.notifier)
        .state = sort.withToggle(col);

    return Container(
      color: AppColors.cardSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          SizedBox(width: _kCbW + _kPriW), // checkbox + priority (not sortable)
          Expanded(
              child: _ColHead('Task', TaskListColumn.task, sort, onSort)),
          _ColHead('Card', TaskListColumn.card, sort, onSort,
              width: _kCardW),
          _ColHead('Card Date', TaskListColumn.cardDate, sort, onSort,
              width: _kDateW),
          _ColHead('Due', TaskListColumn.dueDate, sort, onSort,
              width: _kDueW),
          _ColHead('Where', TaskListColumn.column, sort, onSort,
              width: _kWhereW),
          SizedBox(
            width: _kStatusW,
            child: Text('Status',
                style: Theme.of(context).textTheme.labelMedium,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _ColHead extends StatelessWidget {
  const _ColHead(this.label, this.col, this.sort, this.onSort, {this.width});
  final String label;
  final TaskListColumn col;
  final TaskSortConfig sort;
  final void Function(TaskListColumn) onSort;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final active = sort.column == col;
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: active ? AppColors.accent : AppColors.textTertiary,
                ),
            overflow: TextOverflow.ellipsis),
        if (active) ...[
          const SizedBox(width: 2),
          Icon(
            sort.ascending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 11,
            color: AppColors.accent,
          ),
        ],
      ],
    );

    final inner = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSort(col),
        child: content,
      ),
    );

    return width != null ? SizedBox(width: width, child: inner) : inner;
  }
}

// ── Grid data row ─────────────────────────────────────────────────────────────

class _GridDataRow extends ConsumerStatefulWidget {
  const _GridDataRow({super.key, required this.rowData});
  final _TaskRowData rowData;

  @override
  ConsumerState<_GridDataRow> createState() => _GridDataRowState();
}

class _GridDataRowState extends ConsumerState<_GridDataRow>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _checkAnim;
  late final Animation<double> _checkScale;

  static final _dateFmt = intl.DateFormat('d MMM');

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.rowData.task.isCompleted ? 1.0 : 0.0,
    );
    _checkScale =
        CurvedAnimation(parent: _checkAnim, curve: Curves.elasticOut);
  }

  @override
  void didUpdateWidget(_GridDataRow old) {
    super.didUpdateWidget(old);
    if (widget.rowData.task.isCompleted !=
        old.rowData.task.isCompleted) {
      widget.rowData.task.isCompleted
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
    final task = widget.rowData.task;
    await ref.read(taskRepositoryProvider).markComplete(
          task.id,
          completed: !task.isCompleted,
        );
    ref.read(lastUndoActionProvider.notifier).record(
          TaskCompleted(
              taskId: task.id, wasCompleted: task.isCompleted),
        );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.rowData.task;
    final card = widget.rowData.card;
    final hidden = widget.rowData.isCardHidden;

    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: task.isCompleted
              ? AppColors.textCompleted
              : hidden
                  ? AppColors.textDisabled
                  : AppColors.textPrimary,
          decoration:
              task.isCompleted ? TextDecoration.lineThrough : null,
          decorationColor: AppColors.textCompleted,
        );
    final metaStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textTertiary,
          fontSize: 11,
        );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () =>
            ref.read(selectedTaskIdProvider.notifier).select(task.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _hovered
              ? AppColors.cardSurface
              : Colors.transparent,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox
              SizedBox(
                width: _kCbW,
                child: GestureDetector(
                  onTap: _toggle,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1.0)
                        .animate(_checkScale),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? AppColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: task.isCompleted
                              ? AppColors.accent
                              : AppColors.cardBorder,
                          width: 1.5,
                        ),
                      ),
                      child: task.isCompleted
                          ? const Icon(Icons.check,
                              size: 10,
                              color: AppColors.textInverse)
                          : null,
                    ),
                  ),
                ),
              ),

              // Priority dot
              SizedBox(
                width: _kPriW,
                child: Center(
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: switch (task.priority) {
                        'high' => AppColors.priorityHigh,
                        'low' => AppColors.priorityLow,
                        _ => Colors.transparent,
                      },
                    ),
                  ),
                ),
              ),

              // Task name
              Expanded(
                child: Text(task.title,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),

              // Card title
              SizedBox(
                width: _kCardW,
                child: Text(
                  card?.projectTitle ?? '—',
                  style: metaStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Card date
              SizedBox(
                width: _kDateW,
                child: Text(
                  card != null ? _dateFmt.format(card.date) : '—',
                  style: metaStyle,
                ),
              ),

              // Due date
              SizedBox(
                width: _kDueW,
                child: task.dueDate != null
                    ? _DueDateCell(dueDate: task.dueDate!)
                    : Text('—', style: metaStyle),
              ),

              // Now / Later
              SizedBox(
                width: _kWhereW,
                child: Text(
                  task.columnName == 'now' ? 'Now' : 'Later',
                  style: metaStyle,
                ),
              ),

              // Hidden / Snoozed status
              SizedBox(
                width: _kStatusW,
                child: hidden
                    ? _StatusPill(
                        label: (card?.isHidden ?? false)
                            ? 'Hidden'
                            : 'Snoozed',
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueDateCell extends StatelessWidget {
  const _DueDateCell({required this.dueDate});
  final DateTime dueDate;
  static final _fmt = intl.DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final isOverdue = d.isBefore(today);
    final isToday = d == today;

    return Text(
      isToday ? 'Today' : _fmt.format(dueDate),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: isOverdue
                ? AppColors.overdueText
                : isToday
                    ? AppColors.dueTodayText
                    : AppColors.textTertiary,
            fontWeight: (isOverdue || isToday) ? FontWeight.w600 : null,
          ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 0,
              fontSize: 10,
            ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _stackColor(AppCard card, Map<String, AppStack> stackMap) {
  final stack = stackMap[card.stackId];
  return stack != null ? Color(stack.color) : AppColors.accent;
}
