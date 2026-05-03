import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/database/app_database.dart';
import '../../providers/canvas_providers.dart';
import '../../providers/card_providers.dart';
import '../../providers/stack_providers.dart';
import '../../providers/task_providers.dart';
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
            // Use the effective stack (falls back to first visible stack when
            // no specific stack is selected), so these buttons always work.
            final createStackId =
                ref.watch(effectiveCreateStackProvider);
            if (createStackId == null) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
    void set(CardLayoutMode m) =>
        ref.read(cardLayoutModeProvider.notifier).state = m;

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

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _stackColor(AppCard card, Map<String, AppStack> stackMap) {
  final stack = stackMap[card.stackId];
  return stack != null ? Color(stack.color) : AppColors.accent;
}
