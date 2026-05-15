import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/database/app_database.dart';
import '../../../../domain/undo/undo_action.dart';
import '../../../providers/canvas_providers.dart';
import '../../../providers/card_providers.dart';
import '../../../providers/stack_providers.dart';
import '../../../providers/task_providers.dart';
import '../../../providers/ui_state_providers.dart';
import '../../kanban_view/kanban_view.dart' show showCardKanbanDialog;
import 'card_column_widget.dart';

class IndexCardWidget extends ConsumerStatefulWidget {
  const IndexCardWidget({
    super.key,
    required this.card,
    required this.stackColor,
    this.stackName, // shown as a pill when viewing multiple stacks
  });

  final AppCard card;
  final Color stackColor;
  final String? stackName;

  @override
  ConsumerState<IndexCardWidget> createState() =>
      _IndexCardWidgetState();
}

class _IndexCardWidgetState extends ConsumerState<IndexCardWidget> {
  bool _hovered = false;
  final _addBarKey = GlobalKey<_AddTaskBarState>();

  void _handleEmptyTap(String col) {
    // If detail pane is open, close it; otherwise start adding a task.
    if (ref.read(selectedTaskIdProvider) != null) {
      ref.read(selectedTaskIdProvider.notifier).select(null);
    } else {
      _addBarKey.currentState?._start(col);
    }
  }

  bool get _isArchived => widget.card.status == 'archived';

  bool get _isHiddenOrSnoozed {
    if (_isArchived) return false;
    if (widget.card.isHidden) return true;
    final u = widget.card.hiddenUntil;
    return u != null && u.isAfter(DateTime.now());
  }

  // ── Context menu (header-only right-click) ─────────────────────────────────

  Future<void> _showCardMenu(
      BuildContext context, Offset globalPos) async {
    final card = widget.card;
    final hidden = _isHiddenOrSnoozed;
    final archived = _isArchived;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          globalPos.dx, globalPos.dy, globalPos.dx + 1, globalPos.dy + 1),
      items: [
        if (archived) ...[
          const PopupMenuItem(value: 'restore', child: Text('Restore')),
          const PopupMenuDivider(),
        ] else ...[
          if (hidden)
            const PopupMenuItem(value: 'unhide', child: Text('Unhide'))
          else ...[
            const PopupMenuItem(value: 'hide', child: Text('Hide')),
            const PopupMenuItem(
                value: 'snooze', child: Text('Snooze until…')),
          ],
          const PopupMenuDivider(),
          const PopupMenuItem(
              value: 'kanban', child: Text('Kanban view…')),
          const PopupMenuDivider(),
          const PopupMenuItem(
              value: 'move_stack', child: Text('Move to stack…')),
          const PopupMenuDivider(),
          const PopupMenuItem(
              value: 'del_completed',
              child: Text('Delete completed tasks')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'archive', child: Text('Archive')),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );

    if (!context.mounted) return;

    final repo = ref.read(cardRepositoryProvider);
    final undo = ref.read(lastUndoActionProvider.notifier);

    switch (result) {
      case 'restore':
        await repo.restore(card.id);
      case 'unhide':
        await repo.unhide(card.id);
      case 'hide':
        await repo.hideIndefinitely(card.id);
        undo.record(CardHidden(cardId: card.id));
      case 'snooze':
        await _showSnoozeMenu(context, globalPos, card.id);
      case 'kanban':
        if (context.mounted) await showCardKanbanDialog(context, card);
      case 'move_stack':
        if (context.mounted) await _showMoveToStackMenu(context, globalPos, card.id);
      case 'del_completed':
        await ref.read(taskRepositoryProvider).deleteCompletedForCard(card.id);
      case 'archive':
        await repo.archive(card.id);
        undo.record(
            CardArchived(cardId: card.id, previousStatus: card.status));
      case 'delete':
        await repo.delete(card.id);
        undo.record(CardDeleted(cardId: card.id));
    }
  }

  Future<void> _showSnoozeMenu(
      BuildContext context, Offset pos, String cardId) async {
    final now = DateTime.now();

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          pos.dx + 12, pos.dy + 40, pos.dx + 13, pos.dy + 41),
      items: const [
        PopupMenuItem(value: '2h', child: Text('For 2 hours')),
        PopupMenuItem(
            value: 'tonight', child: Text('Until tonight (8 pm)')),
        PopupMenuItem(
            value: 'tomorrow', child: Text('Until tomorrow (8 am)')),
        PopupMenuItem(value: 'week', child: Text('For a week')),
        PopupMenuItem(value: 'pick', child: Text('Pick a date…')),
      ],
    );

    if (!context.mounted) return;

    DateTime? until;
    switch (result) {
      case '2h':
        until = now.add(const Duration(hours: 2));
      case 'tonight':
        until = DateTime(now.year, now.month, now.day, 20);
      case 'tomorrow':
        until = DateTime(now.year, now.month, now.day + 1, 8);
      case 'week':
        until = now.add(const Duration(days: 7));
      case 'pick':
        final picked = await showDatePicker(
          context: context,
          initialDate: now.add(const Duration(days: 1)),
          firstDate: now,
          lastDate: DateTime(2035),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx)
                  .colorScheme
                  .copyWith(primary: AppColors.accent),
            ),
            child: child!,
          ),
        );
        if (picked != null && context.mounted) {
          until = DateTime(picked.year, picked.month, picked.day, 8);
        }
      default:
        return;
    }

    if (until != null) {
      await ref.read(cardRepositoryProvider).snoozeUntil(cardId, until);
      ref
          .read(lastUndoActionProvider.notifier)
          .record(CardSnoozed(cardId: cardId));
    }
  }

  Future<void> _showMoveToStackMenu(
      BuildContext context, Offset pos, String cardId) async {
    final stacks = ref.read(stacksProvider).valueOrNull ?? [];
    if (stacks.isEmpty) return;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          pos.dx + 12, pos.dy + 40, pos.dx + 13, pos.dy + 41),
      items: stacks
          .map((s) => PopupMenuItem(
                value: s.id,
                enabled: s.id != widget.card.stackId,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Color(s.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(s.name),
                  ],
                ),
              ))
          .toList(),
    );
    if (result != null && result != widget.card.stackId) {
      await ref.read(cardRepositoryProvider).moveToStack(cardId, result);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksForCardProvider(widget.card.id));
    final isSelected =
        ref.watch(selectedCardIdsProvider).contains(widget.card.id);

    // Show a Kanban pill when any task has been moved beyond the first column.
    final columns = ref.watch(boardColumnsProvider).valueOrNull ?? [];
    final firstColId = columns.isNotEmpty ? columns.first.id : null;
    final hasKanbanTasks = tasksAsync.valueOrNull?.any(
          (t) => t.kanbanStageId != null && t.kanbanStageId != firstColId,
        ) ??
        false;

    Color borderColor;
    double borderWidth;
    if (isSelected) {
      borderColor = const Color(0xCC000000); // near-black outline
      borderWidth = 1.5;
    } else if (_isHiddenOrSnoozed || _isArchived) {
      borderColor = AppColors.cardBorder;
      borderWidth = 1;
    } else {
      borderColor = AppColors.cardBorder.withValues(alpha: 0.7);
      borderWidth = 0.5;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: AppSpacing.cardWidth,
        decoration: BoxDecoration(
          color: (_isHiddenOrSnoozed || _isArchived)
              ? AppColors.cardSurface.withValues(alpha: 0.6)
              : _cardTintedColor,
          // Square corners — real 3×5 index cards have no rounding.
          border: Border.all(
            color: borderColor,
            width: borderWidth,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          boxShadow:
              _hovered ? AppShadows.cardHover : AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _CardHeader(
              card: widget.card,
              stackColor: widget.stackColor,
              stackName: widget.stackName,
              isHiddenOrArchived: _isHiddenOrSnoozed || _isArchived,
              isSelected: isSelected,
              hasKanbanTasks: hasKanbanTasks,
              onTap: () {
                final notifier =
                    ref.read(selectedCardIdsProvider.notifier);
                final multiSelect =
                    HardwareKeyboard.instance.isMetaPressed ||
                    HardwareKeyboard.instance.isShiftPressed;
                if (multiSelect) {
                  notifier.toggle(widget.card.id);
                } else {
                  final current = ref.read(selectedCardIdsProvider);
                  if (current.contains(widget.card.id)) {
                    notifier.toggle(widget.card.id);
                  } else {
                    notifier.selectOnly(widget.card.id);
                  }
                }
              },
              onRightClick: (pos) => _showCardMenu(context, pos),
              onTitleSaved: (title) => ref
                  .read(cardRepositoryProvider)
                  .update(id: widget.card.id, projectTitle: title),
              onDateSaved: (date) => ref
                  .read(cardRepositoryProvider)
                  .update(id: widget.card.id, date: date),
            ),

            const Divider(height: 1),

            // Task columns with ruled-paper background.
            tasksAsync.when(
              loading: () => const SizedBox(height: 60),
              error: (e, _) => const SizedBox(height: 60),
              data: (tasks) {
                final now = tasks
                    .where((t) =>
                        t.columnName == 'now' && t.deletedAt == null)
                    .toList();
                final later = tasks
                    .where((t) =>
                        t.columnName == 'later' && t.deletedAt == null)
                    .toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        // Horizontal ruling lines behind the task content.
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RuledLines(
                              color: (_isHiddenOrSnoozed || _isArchived)
                                  ? const Color(0xFFCFDFE8)
                                      .withValues(alpha: 0.5)
                                  : const Color(0xFFCFDFE8),
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                        color: AppColors.divider,
                                        width: 0.5),
                                  ),
                                ),
                                child: CardColumnWidget(
                                  label: 'NOW',
                                  tasks: now,
                                  cardId: widget.card.id,
                                  column: 'now',
                                  isHidden: _isHiddenOrSnoozed,
                                  onEmptyTap: () => _handleEmptyTap('now'),
                                  onEmptySecondaryTap: (pos) =>
                                      _showCardMenu(context, pos),
                                ),
                              ),
                            ),
                            Expanded(
                              child: CardColumnWidget(
                                label: 'LATER',
                                tasks: later,
                                cardId: widget.card.id,
                                column: 'later',
                                isHidden: _isHiddenOrSnoozed,
                                onEmptyTap: () => _handleEmptyTap('later'),
                                onEmptySecondaryTap: (pos) =>
                                    _showCardMenu(context, pos),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // ── Add task bar at card bottom ──────────────────────
                    _AddTaskBar(
                      key: _addBarKey,
                      cardId: widget.card.id,
                      isHidden: _isHiddenOrSnoozed || _isArchived,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color get _cardTintedColor {
    final tint = widget.stackColor.withValues(alpha: 0.025);
    return Color.alphaBlend(tint, AppColors.cardSurface);
  }
}

// ── Card header ───────────────────────────────────────────────────────────────

class _CardHeader extends StatefulWidget {
  const _CardHeader({
    required this.card,
    required this.stackColor,
    required this.isHiddenOrArchived,
    required this.isSelected,
    required this.hasKanbanTasks,
    required this.onTap,
    required this.onRightClick,
    required this.onTitleSaved,
    required this.onDateSaved,
    this.stackName,
  });

  final AppCard card;
  final Color stackColor;
  final bool isHiddenOrArchived;
  final bool isSelected;
  final bool hasKanbanTasks;
  final String? stackName;
  final VoidCallback onTap;
  final void Function(Offset) onRightClick;
  final void Function(String?) onTitleSaved;
  final void Function(DateTime) onDateSaved;

  @override
  State<_CardHeader> createState() => _CardHeaderState();
}

class _CardHeaderState extends State<_CardHeader> {
  bool _editingTitle = false;
  late final TextEditingController _titleCtrl;
  final _titleFocus = FocusNode();

  static final _dateFmt = DateFormat('EEE d MMM yyyy');
  static final _snoozeFmt = DateFormat('d MMM');

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.card.projectTitle ?? '');
    _titleFocus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_CardHeader old) {
    super.didUpdateWidget(old);
    if (!_editingTitle &&
        old.card.projectTitle != widget.card.projectTitle) {
      _titleCtrl.text = widget.card.projectTitle ?? '';
    }
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_onFocusChange);
    _titleCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() => _editingTitle = true);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _titleFocus.requestFocus());
  }

  Future<void> _editDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.card.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) widget.onDateSaved(picked);
  }

  void _onFocusChange() {
    if (!_titleFocus.hasFocus && _editingTitle) _saveTitle();
  }

  void _saveTitle() {
    final text = _titleCtrl.text.trim();
    widget.onTitleSaved(text.isEmpty ? null : text);
    setState(() => _editingTitle = false);
  }

  void _cancelEdit() {
    _titleCtrl.text = widget.card.projectTitle ?? '';
    setState(() => _editingTitle = false);
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final isExpanded = card.status == 'expanded';
    final isArchived = card.status == 'archived';
    final isHidden = !isArchived && card.isHidden;
    final isSnoozed = !isArchived && !isHidden &&
        card.hiddenUntil != null &&
        card.hiddenUntil!.isAfter(DateTime.now());

    // Listener fires on raw pointer events before gesture arenas, so
    // right-click is always detected regardless of nested recognizers.
    // Dark tint for the header when selected.
    final headerBg = widget.isSelected
        ? const Color(0x14000000) // subtle black tint
        : Colors.transparent;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (event.buttons == 0x02) { // kSecondaryMouseButton (right-click)
          widget.onRightClick(event.position);
        }
      },
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: ColoredBox(
        color: headerBg,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colored accent strip
          Container(
            height: 3,
            color: widget.stackColor
                .withValues(alpha: widget.isHiddenOrArchived ? 0.3 : 0.7),
          ),

          // Date + title area
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              10,
              AppSpacing.cardPadding,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date — double-click to change
                          GestureDetector(
                            onDoubleTap: _editDate,
                            child: Text(
                              _dateFmt.format(card.date),
                              style: GoogleFonts.caveat(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Project title — double-click to edit
                          if (_editingTitle)
                            CallbackShortcuts(
                              bindings: {
                                const SingleActivator(
                                    LogicalKeyboardKey.escape): _cancelEdit,
                                const SingleActivator(
                                    LogicalKeyboardKey.enter): _saveTitle,
                              },
                              child: TextField(
                                controller: _titleCtrl,
                                focusNode: _titleFocus,
                                style:
                                    Theme.of(context).textTheme.titleSmall,
                                decoration: InputDecoration(
                                  hintText: 'Project title…',
                                  hintStyle: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                          color: AppColors.textDisabled),
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  border: InputBorder.none,
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: AppColors.accent, width: 1),
                                  ),
                                ),
                                textInputAction: TextInputAction.done,
                              ),
                            )
                          else if (card.projectTitle != null)
                            GestureDetector(
                              onDoubleTap: _startEdit,
                              child: Text(
                                card.projectTitle!,
                                style:
                                    Theme.of(context).textTheme.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else
                            GestureDetector(
                              onDoubleTap: _startEdit,
                              child: Text(
                                'Double-click to add title',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textDisabled,
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isExpanded || widget.hasKanbanTasks)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isExpanded)
                            const Tooltip(
                              message: 'Board',
                              child: Icon(
                                Icons.view_column_outlined,
                                size: 14,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          if (widget.hasKanbanTasks) ...[
                            if (isExpanded) const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => showCardKanbanDialog(
                                  context, widget.card),
                              child: const _KanbanBadge(),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),

                // Status badge (hidden / snoozed / archived)
                if (isArchived || isHidden || isSnoozed) ...[
                  const SizedBox(height: 5),
                  _StatusBadge(
                    label: isArchived
                        ? 'Archived'
                        : isHidden
                            ? 'Hidden'
                            : 'Snoozed until '
                                '${_snoozeFmt.format(card.hiddenUntil!)}',
                  ),
                ],
              ],
            ),
          ),

          // Stack name pill — only shown when viewing multiple stacks
          if (widget.stackName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardPadding, 0, AppSpacing.cardPadding, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.stackColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: widget.stackColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.stackName!,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: widget.stackColor,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
        ), // ColoredBox
      ),     // Column — REMOVED extra wrapping; Column is now child of ColoredBox
      ),     // GestureDetector
    );       // Listener
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});
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
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

// ── Ruled-paper background painter ───────────────────────────────────────────

// ── Add task bar (card bottom) ────────────────────────────────────────────────

class _AddTaskBar extends ConsumerStatefulWidget {
  const _AddTaskBar({
    super.key,
    required this.cardId,
    required this.isHidden,
  });
  final String cardId;
  final bool isHidden;

  @override
  ConsumerState<_AddTaskBar> createState() => _AddTaskBarState();
}

class _AddTaskBarState extends ConsumerState<_AddTaskBar> {
  bool _hovered = false;
  bool _adding = false;
  bool _submitting = false; // guard so focus-lost doesn't cancel mid-submit
  String? _activeColumn; // 'now' | 'later'
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _adding && !_submitting) _cancel();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start(String col) {
    setState(() {
      _adding = true;
      _activeColumn = col;
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _cancel() {
    setState(() {
      _adding = false;
      _ctrl.clear();
    });
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) { _cancel(); return; }
    _ctrl.clear();
    // Keep the bar open for rapid entry — refocus after the DB write.
    _submitting = true;
    await ref.read(taskRepositoryProvider).create(
          cardId: widget.cardId,
          title: text,
          column: _activeColumn ?? 'now',
        );
    _submitting = false;
    if (mounted) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) { if (mounted) _focus.requestFocus(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_adding) {
      return Container(
        height: 26,
        decoration: const BoxDecoration(
          border: Border(
              top: BorderSide(color: AppColors.divider, width: 0.5)),
          color: AppColors.accentLight,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding),
        child: Row(
          children: [
            Icon(Icons.add, size: 12, color: AppColors.accent),
            const SizedBox(width: 6),
            Expanded(
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): _submit,
                  const SingleActivator(LogicalKeyboardKey.escape): _cancel,
                },
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Task title… (${_activeColumn?.toUpperCase()})',
                    hintStyle: const TextStyle(
                        fontSize: 12, color: AppColors.textDisabled),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: _cancel,
              child: const Icon(Icons.close,
                  size: 13, color: AppColors.textTertiary),
            ),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 26,
        decoration: BoxDecoration(
          color: widget.isHidden
              ? Colors.transparent
              : _hovered
                  ? AppColors.accentLight
                  : AppColors.accent.withValues(alpha: 0.05),
          border: const Border(
              top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _start('now'),
                child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    border: Border(
                        right: BorderSide(
                            color: AppColors.divider, width: 0.5)),
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
                        'Now',
                        style: TextStyle(
                          fontSize: 11,
                          color: _hovered
                              ? AppColors.accent
                              : AppColors.textTertiary,
                          fontWeight: _hovered
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _start('later'),
                child: Container(
                  alignment: Alignment.center,
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
                        'Later',
                        style: TextStyle(
                          fontSize: 11,
                          color: _hovered
                              ? AppColors.accent
                              : AppColors.textTertiary,
                          fontWeight: _hovered
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuledLines extends CustomPainter {
  const _RuledLines({required this.color});
  final Color color;

  static const double _spacing = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    var y = _spacing;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += _spacing;
    }
  }

  @override
  bool shouldRepaint(_RuledLines old) => old.color != color;
}

class _KanbanBadge extends StatelessWidget {
  const _KanbanBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.view_week_outlined,
              size: 9, color: AppColors.accent),
          SizedBox(width: 3),
          Text(
            'Kanban',
            style: TextStyle(
              fontSize: 9,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
