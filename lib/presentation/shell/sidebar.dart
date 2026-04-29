import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/enums/app_view.dart';
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
          _SectionLabel('STACKS'),
          const SizedBox(height: 4),

          _StackItem(
            label: 'All Cards',
            dotColor: AppColors.textTertiary,
            isSelected: activeStackId == null,
            onTap: () {
              ref.read(activeStackIdProvider.notifier).set(null);
              if (activeView == AppView.archiveView) {
                ref
                    .read(activeViewProvider.notifier)
                    .set(AppView.cardView);
              }
            },
          ),

          stacks.when(
            data: (list) => Column(
              children: list
                  .map((s) => _StackItem(
                        label: s.name,
                        dotColor: Color(s.color),
                        isSelected: activeStackId == s.id,
                        onTap: () {
                          ref
                              .read(activeStackIdProvider.notifier)
                              .set(s.id);
                          if (activeView == AppView.archiveView) {
                            ref
                                .read(activeViewProvider.notifier)
                                .set(AppView.cardView);
                          }
                        },
                      ))
                  .toList(),
            ),
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

// ── Stack item ────────────────────────────────────────────────────────────────

class _StackItem extends StatefulWidget {
  const _StackItem({
    required this.label,
    required this.dotColor,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color dotColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_StackItem> createState() => _StackItemState();
}

class _StackItemState extends State<_StackItem> {
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
                ? AppColors.sidebarSelected
                : _hovered
                    ? AppColors.sidebarHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: widget.dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
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
            ],
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
