import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/database/app_database.dart';
import '../../../providers/task_providers.dart';
import 'card_column_widget.dart';

class IndexCardWidget extends ConsumerStatefulWidget {
  const IndexCardWidget({
    super.key,
    required this.card,
    required this.stackColor,
  });

  final AppCard card;
  final Color stackColor;

  @override
  ConsumerState<IndexCardWidget> createState() =>
      _IndexCardWidgetState();
}

class _IndexCardWidgetState extends ConsumerState<IndexCardWidget> {
  bool _hovered = false;

  bool get _isHiddenOrSnoozed {
    if (widget.card.isHidden) return true;
    final u = widget.card.hiddenUntil;
    return u != null && u.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync =
        ref.watch(tasksForCardProvider(widget.card.id));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: AppSpacing.cardWidth,
        decoration: BoxDecoration(
          color: _isHiddenOrSnoozed
              ? AppColors.cardSurface.withValues(alpha:0.6)
              : _cardTintedColor,
          borderRadius:
              BorderRadius.circular(AppSpacing.cardRadius),
          border: _isHiddenOrSnoozed
              ? Border.all(
                  color: AppColors.cardBorder,
                  width: 1,
                  strokeAlign: BorderSide.strokeAlignInside,
                )
              : Border.all(
                  color: AppColors.cardBorder.withValues(alpha:0.7),
                  width: 0.5,
                ),
          boxShadow: _hovered
              ? AppShadows.cardHover
              : AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(AppSpacing.cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Accent top strip ───────────────────────────────
              Container(
                height: 3,
                color: widget.stackColor.withValues(alpha:0.7),
              ),

              // ── Header ─────────────────────────────────────────
              _CardHeader(
                card: widget.card,
                stackColor: widget.stackColor,
              ),

              // ── Divider ────────────────────────────────────────
              const Divider(height: 1),

              // ── Task columns ───────────────────────────────────
              tasksAsync.when(
                loading: () => const SizedBox(height: 60),
                error: (e, _) => const SizedBox(height: 60),
                data: (tasks) {
                  final now = tasks
                      .where((t) =>
                          t.columnName == 'now' &&
                          t.deletedAt == null)
                      .toList();
                  final later = tasks
                      .where((t) =>
                          t.columnName == 'later' &&
                          t.deletedAt == null)
                      .toList();

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CardColumnWidget(
                            label: 'NOW',
                            tasks: now,
                            cardId: widget.card.id,
                            column: 'now',
                            isHidden: _isHiddenOrSnoozed,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 0.5,
                          color: AppColors.divider,
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
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Subtle stack-color tint on the card surface.
  Color get _cardTintedColor {
    final tint = widget.stackColor.withValues(alpha:0.025);
    return Color.alphaBlend(tint, AppColors.cardSurface);
  }
}

// ── Card header ───────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.card, required this.stackColor});

  final AppCard card;
  final Color stackColor;

  static final _dateFmt = DateFormat('EEE d MMM');

  @override
  Widget build(BuildContext context) {
    final isExpanded = card.status == 'expanded';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        10,
        AppSpacing.cardPadding,
        8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date in Caveat
                Text(
                  _dateFmt.format(card.date),
                  style: GoogleFonts.caveat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.1,
                  ),
                ),
                if (card.projectTitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    card.projectTitle!,
                    style:
                        Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (isExpanded)
            Tooltip(
              message: 'Board',
              child: Icon(
                Icons.view_column_outlined,
                size: 14,
                color: AppColors.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}
