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
import '../../../providers/task_providers.dart';
import '../../../providers/ui_state_providers.dart';
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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksForCardProvider(widget.card.id));
    final isSelected =
        ref.watch(selectedCardIdsProvider).contains(widget.card.id);

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
          borderRadius:
              BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          boxShadow:
              _hovered ? AppShadows.cardHover : AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(AppSpacing.cardRadius),
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
                onTap: () {
                  final notifier =
                      ref.read(selectedCardIdsProvider.notifier);
                  final multiSelect =
                      HardwareKeyboard.instance.isMetaPressed ||
                      HardwareKeyboard.instance.isShiftPressed;
                  if (multiSelect) {
                    // ⌘/Shift: add or remove without clearing others.
                    notifier.toggle(widget.card.id);
                  } else {
                    // Plain click: select exclusively, or deselect if
                    // this card is already the only selection.
                    final current = ref.read(selectedCardIdsProvider);
                    if (current.contains(widget.card.id)) {
                      notifier.toggle(widget.card.id); // deselect
                    } else {
                      notifier.selectOnly(widget.card.id);
                    }
                  }
                },
                onRightClick: (pos) => _showCardMenu(context, pos),
                onTitleSaved: (title) => ref
                    .read(cardRepositoryProvider)
                    .update(id: widget.card.id, projectTitle: title),
              ),

              const Divider(height: 1),

              // Task columns — Row without IntrinsicHeight to avoid overflow.
              // A right-border on the NOW column acts as the divider.
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

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                  color: AppColors.divider, width: 0.5),
                            ),
                          ),
                          child: CardColumnWidget(
                            label: 'NOW',
                            tasks: now,
                            cardId: widget.card.id,
                            column: 'now',
                            isHidden: _isHiddenOrSnoozed,
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
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
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
    required this.onTap,
    required this.onRightClick,
    required this.onTitleSaved,
    this.stackName,
  });

  final AppCard card;
  final Color stackColor;
  final bool isHiddenOrArchived;
  final bool isSelected;
  final String? stackName;
  final VoidCallback onTap;
  final void Function(Offset) onRightClick;
  final void Function(String?) onTitleSaved;

  @override
  State<_CardHeader> createState() => _CardHeaderState();
}

class _CardHeaderState extends State<_CardHeader> {
  bool _editingTitle = false;
  late final TextEditingController _titleCtrl;
  final _titleFocus = FocusNode();

  static final _dateFmt = DateFormat('EEE d MMM');
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
      onDoubleTap: _startEdit,
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
                          // Date (not editable)
                          Text(
                            _dateFmt.format(card.date),
                            style: GoogleFonts.caveat(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Project title — inline edit on double-tap
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
                            Text(
                              card.projectTitle!,
                              style: Theme.of(context).textTheme.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            Text(
                              'Double-click to add title',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textDisabled,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    if (isExpanded)
                      const Tooltip(
                        message: 'Board',
                        child: Icon(
                          Icons.view_column_outlined,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
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
