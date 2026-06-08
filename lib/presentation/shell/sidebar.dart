import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/database/app_database.dart';
import '../../domain/enums/app_view.dart';
import '../providers/canvas_providers.dart';
import '../providers/card_providers.dart';
import '../providers/export_providers.dart';
import '../providers/stack_providers.dart';
import '../providers/ui_state_providers.dart';
import 'app_view_x.dart';

// ── Top-level helpers (called from both header + right-click) ─────────────────

Future<void> showAddStackDialog(BuildContext context, WidgetRef ref) async {
  final result = await showDialog<({String name, Color color})>(
    context: context,
    builder: (_) => const _AddStackDialog(),
  );
  if (result == null) return;
  final id = await ref
      .read(stackRepositoryProvider)
      .create(name: result.name, color: result.color.toARGB32());
  ref.read(activeStackIdProvider.notifier).set(id);
}

// ── Add stack dialog ──────────────────────────────────────────────────────────

class _AddStackDialog extends StatefulWidget {
  const _AddStackDialog();

  @override
  State<_AddStackDialog> createState() => _AddStackDialogState();
}

class _AddStackDialogState extends State<_AddStackDialog> {
  final _ctrl = TextEditingController();
  Color _color = AppColors.stackPalette[1];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Stack'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Stack name',
              isDense: true,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          Text('Color', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: AppColors.stackPalette.map((c) {
              final active = c == _color;
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: active
                        ? Border.all(color: AppColors.textPrimary, width: 2)
                        : null,
                    boxShadow: active
                        ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 4)]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

// ── Rename stack dialog ───────────────────────────────────────────────────────

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialName});
  final String initialName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Stack'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration:
            const InputDecoration(labelText: 'Stack name', isDense: true),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Rename')),
      ],
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  static const _navViews = [
    AppView.cardView,
    AppView.kanbanView,
    AppView.calendarView,
    AppView.todayView,
    AppView.archiveView,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stacks = ref.watch(stacksProvider);
    final activeStackId = ref.watch(activeStackIdProvider);
    final activeView = ref.watch(activeViewProvider);
    final hiddenIds = ref.watch(hiddenStackIdsProvider);

    return Container(
      width: AppSpacing.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(
          right: BorderSide(color: AppColors.sidebarDivider, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── App title ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
            child: Text(
              '3by5',
              style: GoogleFonts.caveat(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // ── Stacks section ─────────────────────────────────────────────────
          _StacksSectionHeader(),
          const SizedBox(height: 4),

          stacks.when(
            data: (list) {
              final allVisible = hiddenIds.isEmpty;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Master "Show All" row ──────────────────────────────────
                  _AllStacksRow(
                    allVisible: allVisible,
                    onTap: () {
                      ref.read(hiddenStackIdsProvider.notifier).showAll();
                      ref.read(activeStackIdProvider.notifier).set(null);
                      if (activeView == AppView.archiveView) {
                        ref
                            .read(activeViewProvider.notifier)
                            .set(AppView.cardView);
                      }
                    },
                    onRightClick: (pos) async {
                      final result = await showMenu<String>(
                        context: context,
                        position: RelativeRect.fromLTRB(
                            pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
                        items: [
                          const PopupMenuItem(
                            value: 'add',
                            height: 32,
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Text('Add Stack'),
                          ),
                        ],
                      );
                      if (result == 'add' && context.mounted) {
                        await showAddStackDialog(context, ref);
                      }
                    },
                  ),

                  // ── Individual stacks ──────────────────────────────────────
                  ...list.map((s) => _StackItem(
                        stack: s,
                        allStacks: list,
                        isSelected: activeStackId == s.id,
                        onTap: () {
                          final otherIds =
                              list.where((o) => o.id != s.id).map((o) => o.id);
                          ref
                              .read(hiddenStackIdsProvider.notifier)
                              .hideAll(otherIds);
                          ref
                              .read(activeStackIdProvider.notifier)
                              .set(s.id);
                          if (activeView == AppView.archiveView) {
                            ref
                                .read(activeViewProvider.notifier)
                                .set(AppView.cardView);
                          }
                        },
                      )),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
          ),

          const Spacer(),

          // ── Divider ────────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 1),
          ),
          const SizedBox(height: 6),

          // ── Views section ──────────────────────────────────────────────────
          _SectionLabel('VIEWS'),
          const SizedBox(height: 4),

          ..._navViews.map(
            (v) => _ViewNavItem(
              view: v,
              isSelected: activeView == v,
              onTap: () => ref.read(activeViewProvider.notifier).set(v),
            ),
          ),

          // ── Settings gear ──────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 1),
          ),
          const SizedBox(height: 4),
          _SettingsRow(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

// ── Stacks section header ─────────────────────────────────────────────────────

class _StacksSectionHeader extends ConsumerStatefulWidget {
  @override
  ConsumerState<_StacksSectionHeader> createState() =>
      _StacksSectionHeaderState();
}

class _StacksSectionHeaderState extends ConsumerState<_StacksSectionHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
        child: Row(
          children: [
            Text('STACKS', style: Theme.of(context).textTheme.labelMedium),
            const Spacer(),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _hovered ? 1.0 : 0.0,
              child: GestureDetector(
                onTap: () => showAddStackDialog(context, ref),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(Icons.add,
                      size: 14, color: AppColors.textTertiary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── "All stacks" master row ───────────────────────────────────────────────────

class _AllStacksRow extends StatefulWidget {
  const _AllStacksRow({
    required this.allVisible,
    required this.onTap,
    required this.onRightClick,
  });
  final bool allVisible;
  final VoidCallback onTap;
  final void Function(Offset) onRightClick;

  @override
  State<_AllStacksRow> createState() => _AllStacksRowState();
}

class _AllStacksRowState extends State<_AllStacksRow> {
  bool _hovered = false;
  bool _dragOver = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.allVisible;
    return GestureDetector(
      onSecondaryTapUp: (d) => widget.onRightClick(d.globalPosition),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: DragTarget<String>(
          onWillAcceptWithDetails: (_) {
            setState(() => _dragOver = true);
            return true;
          },
          onLeave: (_) => setState(() => _dragOver = false),
          onAcceptWithDetails: (_) => setState(() => _dragOver = false),
          builder: (ctx, candidateData, _) => GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: _dragOver
                    ? AppColors.accent.withValues(alpha: 0.08)
                    : _hovered
                        ? AppColors.sidebarHover
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  // Left accent bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 3,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.accent.withValues(alpha: 0.55)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Icon(
                    Icons.layers_outlined,
                    size: 13,
                    color: isActive
                        ? AppColors.accent
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        'All Stacks',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isActive
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                      ),
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

// ── Stack item ────────────────────────────────────────────────────────────────

class _StackItem extends ConsumerStatefulWidget {
  const _StackItem({
    required this.stack,
    required this.allStacks,
    required this.isSelected,
    required this.onTap,
  });

  final AppStack stack;
  final List<AppStack> allStacks;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  ConsumerState<_StackItem> createState() => _StackItemState();
}

class _StackItemState extends ConsumerState<_StackItem> {
  bool _hovered = false;
  bool _dragOver = false;

  Color get _dotColor => Color(widget.stack.color);

  Future<void> _showContextMenu(BuildContext ctx, Offset pos) async {
    final isLast = widget.allStacks.length <= 1;

    final result = await showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: [
        const PopupMenuItem(
          value: 'add',
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text('Add Stack'),
        ),
        const PopupMenuItem(
          value: 'rename',
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text('Rename'),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'delete',
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          enabled: !isLast,
          child: Tooltip(
            message: isLast ? 'You must have at least one stack' : '',
            child: Text(
              'Delete',
              style: TextStyle(
                color: isLast ? AppColors.textDisabled : AppColors.overdueText,
              ),
            ),
          ),
        ),
      ],
    );

    if (!ctx.mounted) return;

    // Let the menu route fully unmount before opening any secondary dialog.
    // Showing a dialog immediately after showMenu can cause an InheritedElement
    // dependents assertion because the popup route elements haven't been
    // disposed yet when the next route is pushed.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    switch (result) {
      case 'add':
        await showAddStackDialog(context, ref);
      case 'rename':
        await _confirmRename();
      case 'delete':
        await _confirmDelete(context);
    }
  }

  Future<void> _confirmRename() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initialName: widget.stack.name),
    );
    if (newName == null || !mounted) return;
    await ref.read(stackRepositoryProvider).rename(widget.stack.id, newName);
  }

  Future<void> _confirmDelete(BuildContext ctx) async {
    final remaining = widget.allStacks
        .where((s) => s.id != widget.stack.id)
        .toList();
    if (remaining.isEmpty) return;

    await showDialog<void>(
      context: ctx,
      builder: (dCtx) => _DeleteStackDialog(
        stack: widget.stack,
        remainingStacks: remaining,
      ),
    );
  }

  Future<void> _onCardDropped(String cardId) async {
    setState(() => _dragOver = false);
    final card = await ref.read(cardRepositoryProvider).getById(cardId);
    if (card == null || card.stackId == widget.stack.id) return;
    await ref.read(cardRepositoryProvider).moveToStack(cardId, widget.stack.id);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: DragTarget<String>(
          onWillAcceptWithDetails: (_) {
            setState(() => _dragOver = true);
            return true;
          },
          onLeave: (_) => setState(() => _dragOver = false),
          onAcceptWithDetails: (d) => _onCardDropped(d.data),
          builder: (ctx, candidateData, _) => GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: _dragOver
                    ? _dotColor.withValues(alpha: 0.10)
                    : widget.isSelected
                        ? AppColors.sidebarSelected
                        : _hovered
                            ? AppColors.sidebarHover
                            : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  // Left accent bar (stack color when selected)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 3,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? _dotColor
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  // Stack color dot
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  // Stack name
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        widget.stack.name,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: widget.isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: widget.isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                      ),
                    ),
                  ),
                  // Delete/rename button — hover-reveal
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _hovered ? 1.0 : 0.0,
                    child: GestureDetector(
                      onTap: () =>
                          _showContextMenu(context, _menuOffset(context)),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8, left: 4),
                        child: Icon(Icons.more_horiz,
                            size: 14, color: AppColors.textTertiary),
                      ),
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

  Offset _menuOffset(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.localToGlobal(Offset(box.size.width, box.size.height / 2));
  }
}

// ── Delete stack dialog ───────────────────────────────────────────────────────

class _DeleteStackDialog extends ConsumerStatefulWidget {
  const _DeleteStackDialog({
    required this.stack,
    required this.remainingStacks,
  });

  final AppStack stack;
  final List<AppStack> remainingStacks;

  @override
  ConsumerState<_DeleteStackDialog> createState() => _DeleteStackDialogState();
}

class _DeleteStackDialogState extends ConsumerState<_DeleteStackDialog> {
  late String _targetStackId;
  bool _deleteCards = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _targetStackId = widget.remainingStacks.first.id;
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final cardRepo = ref.read(cardRepositoryProvider);
      final stackRepo = ref.read(stackRepositoryProvider);

      if (_deleteCards) {
        await cardRepo.deleteAllByStack(widget.stack.id);
      } else {
        await cardRepo.moveAllActiveToStack(widget.stack.id, _targetStackId);
      }

      await stackRepo.delete(widget.stack.id);

      // Housekeep active stack and hidden stack state.
      if (ref.read(activeStackIdProvider) == widget.stack.id) {
        ref.read(activeStackIdProvider.notifier).set(_targetStackId);
      }
      ref.read(hiddenStackIdsProvider.notifier).remove(widget.stack.id);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Delete "${widget.stack.name}"?'),
      content: RadioGroup<bool>(
        groupValue: _deleteCards,
        onChanged: (v) => setState(() => _deleteCards = v!),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Move option (default)
            const RadioListTile<bool>(
              value: false,
              contentPadding: EdgeInsets.zero,
              title: Text('Move cards to'),
            ),
            if (!_deleteCards)
              Padding(
                padding: const EdgeInsets.only(left: 36, bottom: 8),
                child: DropdownButton<String>(
                  value: _targetStackId,
                  isExpanded: true,
                  items: widget.remainingStacks
                      .map((s) => DropdownMenuItem(
                            value: s.id,
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
                  onChanged: (id) {
                    if (id != null) setState(() => _targetStackId = id);
                  },
                ),
              ),
            // Delete-all option
            const RadioListTile<bool>(
              value: true,
              contentPadding: EdgeInsets.zero,
              title: Text('Delete all cards in this stack'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy ? null : _confirm,
          style: TextButton.styleFrom(
            foregroundColor:
                _deleteCards ? AppColors.overdueText : AppColors.accent,
          ),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              : Text(_deleteCards ? 'Delete All' : 'Move & Delete Stack'),
        ),
      ],
    );
  }
}

// ── View nav item ─────────────────────────────────────────────────────────────

class _ViewNavItem extends StatefulWidget {
  const _ViewNavItem({
    required this.view,
    required this.isSelected,
    required this.onTap,
  });

  final AppView view;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ViewNavItem> createState() => _ViewNavItemState();
}

class _ViewNavItemState extends State<_ViewNavItem> {
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
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.sidebarViewSelected
                : _hovered
                    ? AppColors.sidebarHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                widget.view.icon,
                size: 15,
                color: widget.isSelected
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                widget.view.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: widget.isSelected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Settings row ──────────────────────────────────────────────────────────────

class _SettingsRow extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends ConsumerState<_SettingsRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () =>
            ref.read(settingsPanelVisibleProvider.notifier).state = true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.sidebarHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(Icons.settings_outlined,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Text(
                'Settings',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
