import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/enums/app_view.dart';
import '../providers/canvas_providers.dart';
import '../providers/stack_providers.dart';
import '../providers/ui_state_providers.dart';
import 'app_view_x.dart';

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
              final hiddenIds = ref.watch(hiddenStackIdsProvider);
              final allVisible = hiddenIds.isEmpty;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Master "Show All" row ─────────────────────────────────
                  _AllStacksRow(
                    allVisible: allVisible,
                    onTap: () {
                      // Always show all — never hide everything from here.
                      ref.read(hiddenStackIdsProvider.notifier).showAll();
                      if (activeView == AppView.archiveView) {
                        ref
                            .read(activeViewProvider.notifier)
                            .set(AppView.cardView);
                      }
                    },
                  ),
                  // ── Individual stacks ─────────────────────────────────────
                  ...list.map((s) => _StackItem(
                        label: s.name,
                        dotColor: Color(s.color),
                        isSelected: activeStackId == s.id,
                        isVisible: !hiddenIds.contains(s.id),
                        onTap: () {
                          // Clicking a stack name: show ONLY this stack by
                          // hiding all others.  This is the "navigate to stack"
                          // action and also sets the creation target.
                          final otherIds = list
                              .where((o) => o.id != s.id)
                              .map((o) => o.id);
                          ref
                              .read(hiddenStackIdsProvider.notifier)
                              .hideAll(otherIds);
                          ref.read(activeStackIdProvider.notifier).set(s.id);
                          if (activeView == AppView.archiveView) {
                            ref
                                .read(activeViewProvider.notifier)
                                .set(AppView.cardView);
                          }
                        },
                        onToggleVisible: () => ref
                            .read(hiddenStackIdsProvider.notifier)
                            .toggle(s.id),
                        onDelete: () async {
                          await ref
                              .read(stackRepositoryProvider)
                              .delete(s.id);
                          ref
                              .read(hiddenStackIdsProvider.notifier)
                              .toggle(s.id); // remove from hidden too
                          if (ref.read(activeStackIdProvider) == s.id) {
                            ref
                                .read(activeStackIdProvider.notifier)
                                .set(null);
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
              onTap: () =>
                  ref.read(activeViewProvider.notifier).set(v),
            ),
          ),

          const SizedBox(height: 16),
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
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

// ── Stacks section header (label + add button) ────────────────────────────────

class _StacksSectionHeader extends ConsumerStatefulWidget {
  @override
  ConsumerState<_StacksSectionHeader> createState() =>
      _StacksSectionHeaderState();
}

class _StacksSectionHeaderState extends ConsumerState<_StacksSectionHeader> {
  bool _hovered = false;

  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    var selectedColor = AppColors.stackPalette[1]; // default non-blue

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('New Stack'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Stack name',
                  isDense: true,
                ),
                onSubmitted: (_) => _create(ctx, controller, selectedColor),
              ),
              const SizedBox(height: 14),
              Text('Color',
                  style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: AppColors.stackPalette.map((c) {
                  final active = c == selectedColor;
                  return GestureDetector(
                    onTap: () => setS(() => selectedColor = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: active
                            ? Border.all(
                                color: AppColors.textPrimary, width: 2)
                            : null,
                        boxShadow: active
                            ? [
                                BoxShadow(
                                    color: c.withValues(alpha: 0.4),
                                    blurRadius: 4)
                              ]
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => _create(ctx, controller, selectedColor),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _create(BuildContext ctx, TextEditingController controller,
      Color color) async {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    final id = await ref
        .read(stackRepositoryProvider)
        .create(name: name, color: color.toARGB32());
    if (ctx.mounted) Navigator.pop(ctx);
    ref.read(activeStackIdProvider.notifier).set(id);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
        child: Row(
          children: [
            Text('STACKS',
                style: Theme.of(context).textTheme.labelMedium),
            const Spacer(),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _hovered ? 1.0 : 0.0,
              child: GestureDetector(
                onTap: () => _showAddDialog(context),
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
  const _AllStacksRow({required this.allVisible, required this.onTap});
  final bool allVisible;
  final VoidCallback onTap;

  @override
  State<_AllStacksRow> createState() => _AllStacksRowState();
}

class _AllStacksRowState extends State<_AllStacksRow> {
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
            color: _hovered ? AppColors.sidebarHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: Checkbox(
                  value: widget.allVisible,
                  onChanged: (_) => widget.onTap(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: AppColors.textTertiary, width: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'All Stacks',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stack item ────────────────────────────────────────────────────────────────

class _StackItem extends StatefulWidget {
  const _StackItem({
    required this.label,
    required this.dotColor,
    required this.isSelected,
    required this.isVisible,
    required this.onTap,
    required this.onToggleVisible,
    this.onDelete,
  });

  final String label;
  final Color dotColor;
  final bool isSelected;
  final bool isVisible;
  final VoidCallback onTap;
  final VoidCallback onToggleVisible;
  final Future<void> Function()? onDelete;

  @override
  State<_StackItem> createState() => _StackItemState();
}

class _StackItemState extends State<_StackItem> {
  bool _hovered = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete stack?'),
        content: const Text(
            'The stack will be removed from the sidebar. Cards in this '
            'stack will remain accessible via All Cards.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.overdueText),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onDelete?.call();
  }

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
                ? AppColors.sidebarSelected
                : _hovered
                    ? AppColors.sidebarHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Opacity(
            opacity: widget.isVisible ? 1.0 : 0.45,
            child: Row(
              children: [
                // Visibility checkbox (uses stack color when checked)
                GestureDetector(
                  onTap: widget.onToggleVisible,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: Checkbox(
                      value: widget.isVisible,
                      onChanged: (_) => widget.onToggleVisible(),
                      activeColor: widget.dotColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(
                          color: widget.dotColor.withValues(alpha: 0.6),
                          width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Stack color dot
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    widget.label,
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
                // Delete button — hover-reveal
                if (widget.onDelete != null)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _hovered ? 1.0 : 0.0,
                    child: GestureDetector(
                      onTap: _confirmDelete,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.close,
                            size: 12, color: AppColors.textTertiary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
