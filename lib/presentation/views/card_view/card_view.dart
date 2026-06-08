import 'dart:collection';
import 'dart:math' as math;

import 'package:intl/intl.dart' as intl;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/undo/undo_action.dart';
import '../../providers/canvas_providers.dart';
import '../../providers/card_providers.dart';
import '../../providers/card_view_settings_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/stack_providers.dart';
import '../../providers/tag_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/ui_state_providers.dart';
import '../../../domain/enums/app_view.dart';
import '../../widgets/zoom_indicator.dart';
import '../../widgets/zoomed_view_area.dart';
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
            final cardContent = switch (layoutMode) {
              CardLayoutMode.grid =>
                _GridView(cards: cards, stackMap: stackMap, showStackPill: showStackPill),
              CardLayoutMode.scattered =>
                _ScatteredView(
                    key: ValueKey(activeStackId ?? 'all'),
                    cards: cards,
                    stackMap: stackMap,
                    showStackPill: showStackPill),
              CardLayoutMode.canvas =>
                _CanvasView(cards: cards, stackMap: stackMap, showStackPill: showStackPill),
              CardLayoutMode.taskList =>
                const _TaskListView(),
            };
            // Canvas has its own InteractiveViewer — exclude from zoom capture.
            if (layoutMode == CardLayoutMode.canvas) return cardContent;
            return ZoomedViewArea(view: AppView.cardView, child: cardContent);
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
            final showGenerate = ref.watch(showGenerateButtonProvider);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DeleteCompletedButton(),
                const SizedBox(width: 8),
                if (showGenerate) ...[
                  _GenerateButton(stackId: createStackId),
                  const SizedBox(width: 8),
                ],
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
          icon: Icons.style_outlined,
          tooltip: 'Stack view',
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
          icon: Icons.grid_view_rounded,
          tooltip: 'Sorted grid',
          active: current == CardLayoutMode.grid,
          onTap: () => set(CardLayoutMode.grid),
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
                  ? Colors.white.withValues(alpha: 0.22)
                  : _hovered
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.viewPadding, 0,
          AppSpacing.viewPadding, AppSpacing.viewPadding),
      child: Wrap(
          spacing: AppSpacing.cardGap * CardZoomData.of(context),
          runSpacing: AppSpacing.cardGap * CardZoomData.of(context),
          children: cards
              .map((c) => IndexCardWidget(
                    card: c,
                    stackColor: _stackColor(c, stackMap),
                    stackName: showStackPill ? stackMap[c.stackId]?.name : null,
                  ))
              .toList(),
      ),
    );
  }
}

// ── Scattered layout — flip-card deck ────────────────────────────────────────

class _ScatteredView extends ConsumerStatefulWidget {
  const _ScatteredView(
      {super.key,
      required this.cards,
      required this.stackMap,
      required this.showStackPill});
  final List<AppCard> cards;
  final Map<String, AppStack> stackMap;
  final bool showStackPill;

  @override
  ConsumerState<_ScatteredView> createState() => _ScatteredViewState();
}

// ── Stack view constants (all tunable here) ───────────────────────────────────

const _kDiscardFraction  = 0.20;    // discard zone fraction (smaller = depth illusion)
const _kGapFraction      = 0.06;    // gap between zones
const _kDrawFraction     = 0.74;    // draw zone fraction (wider = more card room)
const _kMaxTotalWidth    = 1400.0;  // cap before centering on wide windows
const kDiscardPileScale  = 0.22;    // discard backs rendered at 22% of main card width
const _kFlipMs           = 400;     // flip animation ms
const _kArcPeakHeight    = 68.0;    // px the arc peaks above the midpoint
const _kPeekCount        = 4;       // card-edge layers beneath current card
const _kPeekDx           = 5.0;     // horizontal offset per peek layer
const _kPeekDy           = 4.0;     // vertical offset per peek layer
const _kPerspective      = 0.0015;  // Matrix4 [3,2] perspective entry
const _kMaxShadowCards   = 8.0;     // clamp for shadow-depth parameter
const _kNavBtnSize       = 48.0;    // nav arrow button diameter
const _kCardTopPad       = 52.0;    // vertical padding above card zones
const _kCardBackH        = 280.0;   // reference height for _CardBack widget
const _kDotSize          = 7.0;     // position-indicator dot diameter

// ── Layout metrics ────────────────────────────────────────────────────────────

class _Metrics {
  const _Metrics({
    required this.totalW,
    required this.hOffset,
    required this.discardLeft,
    required this.discardW,
    required this.drawLeft,
    required this.drawW,
    required this.cardW,
    required this.drawCardLeft,
    required this.discardCardLeft,
    required this.scale,
  });

  final double totalW;
  final double hOffset;
  final double discardLeft;
  final double discardW;
  final double drawLeft;
  final double drawW;
  final double cardW;
  final double drawCardLeft;
  final double discardCardLeft;
  final double scale;

  static _Metrics from(BoxConstraints c, double scale) {
    final totalW = math.min(c.maxWidth, _kMaxTotalWidth);
    final hOffset = (c.maxWidth - totalW) / 2;
    final discardW = totalW * _kDiscardFraction;
    final drawW = totalW * _kDrawFraction;
    final drawLeft = hOffset;
    final discardLeft = hOffset + drawW + totalW * _kGapFraction;
    final cardW = math.min(AppSpacing.cardWidth.toDouble() * scale, drawW - 32.0);
    return _Metrics(
      totalW: totalW,
      hOffset: hOffset,
      discardLeft: discardLeft,
      discardW: discardW,
      drawLeft: drawLeft,
      drawW: drawW,
      cardW: cardW,
      drawCardLeft: drawLeft + (drawW - cardW) / 2,
      discardCardLeft: discardLeft + (discardW - cardW) / 2,
      scale: scale,
    );
  }

  Offset get drawCardCenter =>
      Offset(drawCardLeft + cardW / 2, _kCardTopPad * scale + _kCardBackH * scale / 2);
  Offset get discardCardCenter =>
      Offset(discardCardLeft + cardW / 2, _kCardTopPad * scale + _kCardBackH * scale / 2);
  // The actual visual center of the small discard-pile back (scaled down).
  Offset get discardPileCenter =>
      Offset(discardCardLeft + cardW / 2,
             _kCardTopPad * scale + _kCardBackH * scale * kDiscardPileScale / 2);

  @override
  bool operator ==(Object other) =>
      other is _Metrics &&
      other.totalW == totalW &&
      other.hOffset == hOffset &&
      other.cardW == cardW;
  @override
  int get hashCode => Object.hash(totalW, hOffset, cardW);
}

// ── Cubic bezier arc tween ────────────────────────────────────────────────────

class _ArcTween extends Animatable<Offset> {
  const _ArcTween({required this.begin, required this.end});
  final Offset begin;
  final Offset end;

  @override
  Offset transform(double t) {
    // Cubic bezier: control points peak above the midpoint.
    final midY = math.min(begin.dy, end.dy) - _kArcPeakHeight;
    final midX = (begin.dx + end.dx) / 2;
    final span = (end.dx - begin.dx).abs() * 0.25;
    final dir = end.dx > begin.dx ? 1.0 : -1.0;
    final p0 = begin;
    final p1 = Offset(midX - span * dir, midY);
    final p2 = Offset(midX + span * dir, midY);
    final p3 = end;
    // De Casteljau
    final b01 = Offset.lerp(p0, p1, t)!;
    final b12 = Offset.lerp(p1, p2, t)!;
    final b23 = Offset.lerp(p2, p3, t)!;
    final c01 = Offset.lerp(b01, b12, t)!;
    final c12 = Offset.lerp(b12, b23, t)!;
    return Offset.lerp(c01, c12, t)!;
  }
}

// ── Stack view state ──────────────────────────────────────────────────────────

class _ScatteredViewState extends ConsumerState<_ScatteredView>
    with TickerProviderStateMixin {

  int _idx = 0;

  late final FocusNode _focusNode;

  // Two independent controllers driven simultaneously.
  late final AnimationController _rotCtrl; // rotation  0→1 → rotateY(0→π)
  late final AnimationController _posCtrl; // position  0→1 → arc Offset

  _ArcTween? _arcTween;
  bool _activeForward = true;

  // Proper flip queue — rapid taps queue without interrupting in-flight cards.
  final Queue<bool> _queue = Queue<bool>();
  bool _isAnimating = false;

  // Prevents trackpad pan gesture from flipping more than one card per swipe.
  bool _panFlipDone = false;

  // Latest layout metrics cached from LayoutBuilder.
  _Metrics? _metrics;

  List<AppCard> get _sorted =>
      [...widget.cards]..sort((a, b) => b.date.compareTo(a.date));

  String get _posKey {
    final k = widget.key;
    return k is ValueKey<String> ? k.value : 'all';
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'CardStackFocus');
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kFlipMs),
    );
    _posCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kFlipMs),
    );
    _rotCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _completeFlip();
    });
    // Restore position: in-memory cache is instant (survives stack switches);
    // DB read is the fallback for app-restart case.
    final cached = ref.read(deckPositionCacheProvider)[_posKey];
    if (cached != null) {
      _idx = cached.clamp(0, widget.cards.isEmpty ? 0 : widget.cards.length - 1);
    } else {
      Future.microtask(_restorePosition);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _restorePosition() async {
    if (!mounted) return;
    final stored =
        await ref.read(settingsDaoProvider).get('deckPos_$_posKey');
    if (!mounted) return;
    if (stored != null) {
      final parsed = int.tryParse(stored);
      if (parsed != null) {
        final n = _sorted.length;
        final clamped = parsed.clamp(0, n > 0 ? n - 1 : 0);
        setState(() => _idx = clamped);
        // Populate the in-memory cache so subsequent stack switches
        // restore instantly without an async DB round-trip.
        ref.read(deckPositionCacheProvider.notifier).save(_posKey, clamped);
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _rotCtrl.dispose();
    _posCtrl.dispose();
    super.dispose();
  }

  // ── Queue management ──────────────────────────────────────────────────────

  void _requestFlip(bool forward) {
    final n = _sorted.length;
    if (forward && _idx >= n - 1) return;
    if (!forward && _idx <= 0) return;
    _queue.addLast(forward);
    _processQueue();
  }

  void _processQueue() {
    if (_isAnimating || _queue.isEmpty) return;
    _isAnimating = true;
    _activeForward = _queue.removeFirst();
    _executeFlip();
  }

  void _executeFlip() {
    final m = _metrics;
    if (m == null) { _isAnimating = false; return; }
    _arcTween = _activeForward
        ? _ArcTween(begin: m.drawCardCenter, end: m.discardPileCenter)
        : _ArcTween(begin: m.discardPileCenter, end: m.drawCardCenter);
    _rotCtrl.forward(from: 0);
    _posCtrl.forward(from: 0);
  }

  void _completeFlip() {
    _posCtrl.stop();
    setState(() {
      _idx = _activeForward ? _idx + 1 : _idx - 1;
      _isAnimating = false;
    });
    _rotCtrl.reset();
    _posCtrl.reset();
    _savePosition();
    _processQueue();
  }

  void _jumpTo(int targetIdx) {
    final n = _sorted.length;
    final clamped = targetIdx.clamp(0, n > 0 ? n - 1 : 0);
    if (clamped == _idx) return;
    setState(() => _idx = clamped);
    _savePosition();
  }

  void _savePosition() {
    ref.read(deckPositionCacheProvider.notifier).save(_posKey, _idx);
    ref.read(settingsDaoProvider).set('deckPos_$_posKey', _idx.toString()).ignore();
  }

  // ── Smooth shadow depths ──────────────────────────────────────────────────

  double _drawShadow(int n) {
    final base = (n - _idx - 1).toDouble();
    if (!_isAnimating) return base.clamp(0, _kMaxShadowCards);
    final delta = _posCtrl.value;
    return (_activeForward ? base - delta : base + delta).clamp(0, _kMaxShadowCards);
  }

  double _discardShadow() {
    final base = _idx.toDouble();
    if (!_isAnimating) return base.clamp(0, _kMaxShadowCards);
    final delta = _posCtrl.value;
    return (_activeForward ? base + delta : base - delta).clamp(0, _kMaxShadowCards);
  }

  // ── Window resize handling ────────────────────────────────────────────────

  void _handleResize(BoxConstraints c, double scale) {
    final m = _Metrics.from(c, scale);
    if (m == _metrics) return;
    _metrics = m;
    if (_isAnimating) {
      // Snap animation to completion, recompute arc with new metrics.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _rotCtrl.value = 1.0;
        _posCtrl.value = 1.0;
        _completeFlip();
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scale = CardZoomData.of(context);
    final cards = _sorted;
    final n = cards.length;
    if (n == 0) return const _EmptyState();

    final cur = _idx.clamp(0, n - 1);
    final current = cards[cur];
    final curColor = _stackColor(current, widget.stackMap);
    final canFwd = cur < n - 1;
    final canBwd = cur > 0;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _requestFlip(true);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _requestFlip(false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: (_) => _focusNode.requestFocus(),
        onPointerPanZoomStart: (_) { _panFlipDone = false; },
        onPointerPanZoomUpdate: (ev) {
          if (_panFlipDone) return;
          final dx = ev.panDelta.dx;
          if (dx > 18) {
            _requestFlip(false);
            _panFlipDone = true;
          } else if (dx < -18) {
            _requestFlip(true);
            _panFlipDone = true;
          }
        },
        child: LayoutBuilder(builder: (context, constraints) {
          _handleResize(constraints, scale);
          final m = _Metrics.from(constraints, scale);
          final anim = Listenable.merge([_rotCtrl, _posCtrl]);

          return AnimatedBuilder(
            animation: anim,
            builder: (ctx, _) {
              final drawSh = _drawShadow(n);
              final discSh = _discardShadow();

              // ── arc position of the flying card ──────────────────
              final posT = CurvedAnimation(
                parent: _posCtrl, curve: Curves.easeInOut).value;
              final arcOffset = _arcTween?.transform(posT) ?? m.drawCardCenter;

              // ── scale: shrink to kDiscardPileScale as card lands ──
              final flyScale = _activeForward
                  ? 1.0 - posT * (1.0 - kDiscardPileScale)
                  : kDiscardPileScale + posT * (1.0 - kDiscardPileScale);

              // ── rotateY angle ─────────────────────────────────────
              final rotT = CurvedAnimation(
                parent: _rotCtrl, curve: Curves.easeInOut).value;
              final angle = rotT * math.pi;
              final isFront = angle < math.pi / 2;
              // displayAngle trick: both front and back faces render right-reading.
              final displayAngle = isFront ? angle : angle - math.pi;

              // Which card and face is the flying widget showing?
              // Forward: card leaves draw (shows front, then back).
              // Backward: card returns from discard (shows back, then front).
              final flyingCard = _activeForward ? current : cards[math.max(0, cur - 1)];
              final flyingShowFront = _activeForward ? isFront : !isFront;
              final flyingColor = _stackColor(flyingCard, widget.stackMap);

              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [

                  // ── Discard pile (right zone, FIXED) ─────────────
                  if (cur > 0 || (_isAnimating && !_activeForward))
                    Positioned(
                      left: m.discardLeft,
                      top: _kCardTopPad * scale,
                      width: m.discardW,
                      child: _DiscardZone(
                        count: _isAnimating && !_activeForward ? cur - 1 : cur,
                        topColor: cur > 0
                            ? _stackColor(cards[cur - 1], widget.stackMap)
                            : curColor,
                        shadowDepth: discSh,
                        cardW: m.cardW,
                        zoneW: m.discardW,
                        scale: scale,
                      ),
                    ),

                  // ── Draw stack (left zone, PIXEL-STABLE ANCHOR) ───
                  Positioned(
                    left: m.drawLeft,
                    top: _kCardTopPad * scale,
                    width: m.drawW,
                    child: _DrawZone(
                      card: _isAnimating ? null : current,
                      stackColor: curColor,
                      stackName: widget.showStackPill
                          ? widget.stackMap[current.stackId]?.name
                          : null,
                      remaining: n - cur - 1,
                      shadowDepth: drawSh,
                      cardW: m.cardW,
                      zoneW: m.drawW,
                      scale: scale,
                    ),
                  ),

                  // ── Flying card overlay (during animation) ────────
                  if (_isAnimating)
                    Positioned(
                      left: arcOffset.dx - m.cardW / 2,
                      top: arcOffset.dy - _kCardBackH * scale / 2,
                      width: m.cardW,
                      child: IgnorePointer(
                        child: Transform.scale(
                          scale: flyScale,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, _kPerspective)
                              ..rotateY(displayAngle),
                            child: flyingShowFront
                              ? IndexCardWidget(
                                  card: flyingCard,
                                  stackColor: flyingColor,
                                  stackName: widget.showStackPill
                                      ? widget.stackMap[flyingCard.stackId]?.name
                                      : null,
                                )
                              : _CardBack(
                                  stackColor: flyingColor,
                                  cardW: m.cardW,
                                  scale: scale,
                                ),
                          ),  // Transform (flip)
                        ),  // Transform.scale
                      ),  // IgnorePointer
                    ),

                  // ── Left nav arrow ────────────────────────────────
                  Positioned(
                    left: 16,
                    top: _kCardTopPad * scale + _kCardBackH * scale / 2 - _kNavBtnSize / 2,
                    child: _NavBtn(
                      icon: Icons.chevron_left,
                      enabled: canBwd,
                      onTap: () => _requestFlip(false),
                    ),
                  ),

                  // ── Right nav arrow ───────────────────────────────
                  Positioned(
                    right: 16,
                    top: _kCardTopPad * scale + _kCardBackH * scale / 2 - _kNavBtnSize / 2,
                    child: _NavBtn(
                      icon: Icons.chevron_right,
                      enabled: canFwd,
                      onTap: () => _requestFlip(true),
                    ),
                  ),

                  // ── Counter + dot indicator ───────────────────────
                  Positioned(
                    left: m.hOffset,
                    width: m.totalW,
                    top: _kCardTopPad * scale + _kCardBackH * scale + 20,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _JumpBtn(
                              icon: Icons.first_page,
                              tooltip: 'Newest card',
                              enabled: canBwd,
                              onTap: () => _jumpTo(0),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${cur + 1} of $n',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _JumpBtn(
                              icon: Icons.last_page,
                              tooltip: 'Oldest card',
                              enabled: canFwd,
                              onTap: () => _jumpTo(n - 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _DotIndicator(
                          total: n,
                          current: cur,
                          onTap: _jumpTo,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        }),
      ),
    );
  }
}

// ── Draw stack zone ───────────────────────────────────────────────────────────

class _DrawZone extends StatelessWidget {
  const _DrawZone({
    required this.card,
    required this.stackColor,
    required this.stackName,
    required this.remaining,
    required this.shadowDepth,
    required this.cardW,
    required this.zoneW,
    required this.scale,
  });

  final AppCard? card;
  final Color stackColor;
  final String? stackName;
  final int remaining;
  final double shadowDepth;
  final double cardW;
  final double zoneW;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final peeks = math.min(remaining, _kPeekCount);
    final cardLeft = (zoneW - cardW) / 2;
    final cardBackH = _kCardBackH * scale;
    final peekDy = _kPeekDy * scale;
    final peekDx = _kPeekDx * scale;

    return SizedBox(
      width: zoneW,
      height: cardBackH + peeks * peekDy + 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Stack-depth shadow (proportional to remaining) ────────
          if (shadowDepth > 0)
            Positioned(
              left: cardLeft,
              top: 0,
              width: cardW,
              height: cardBackH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: 0.28 * shadowDepth / _kMaxShadowCards),
                      blurRadius: 10 + shadowDepth * 2,
                      offset: Offset(5 + shadowDepth * 0.6,
                          8 + shadowDepth * 0.9),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: 0.12 * shadowDepth / _kMaxShadowCards),
                      blurRadius: 28 + shadowDepth * 3,
                      offset: Offset(10 + shadowDepth, 16 + shadowDepth),
                    ),
                  ],
                ),
              ),
            ),

          // ── Peek layers (cards below, edges sticking out) ─────────
          for (var i = peeks; i >= 1; i--)
            Positioned(
              left: cardLeft + i * peekDx,
              top: i * peekDy,
              width: cardW,
              height: cardBackH,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardSurface.withValues(
                      alpha: 0.55 + (peeks - i) * 0.06),
                  border: Border.all(
                      color: AppColors.cardBorder
                          .withValues(alpha: 0.6 + (peeks - i) * 0.1),
                      width: 0.5),
                ),
              ),
            ),

          // ── Current card (on top, interactive) ────────────────────
          if (card != null)
            Positioned(
              left: cardLeft,
              top: 0,
              width: cardW,
              child: IndexCardWidget(
                card: card!,
                stackColor: stackColor,
                stackName: stackName,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Discard pile zone ─────────────────────────────────────────────────────────

class _DiscardZone extends StatelessWidget {
  const _DiscardZone({
    required this.count,
    required this.topColor,
    required this.shadowDepth,
    required this.cardW,
    required this.zoneW,
    required this.scale,
  });

  final int count;
  final Color topColor;
  final double shadowDepth;
  final double cardW;
  final double zoneW;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final peeks = math.min(count - 1, _kPeekCount);

    // Perspective: discard backs are a fraction of the main card size.
    final backW = cardW * kDiscardPileScale;
    final backH = _kCardBackH * scale * kDiscardPileScale;
    final backLeft = (zoneW - backW) / 2;
    final peekDy = _kPeekDy * scale * kDiscardPileScale;
    final peekDx = _kPeekDx * scale * kDiscardPileScale;

    return SizedBox(
      width: zoneW,
      height: backH + peeks * peekDy + 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Shadow beneath the small back ─────────────────────────
          if (shadowDepth > 0)
            Positioned(
              left: backLeft,
              top: 0,
              width: backW,
              height: backH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: 0.28 * shadowDepth / _kMaxShadowCards),
                      blurRadius: 10 + shadowDepth * 2,
                      offset: Offset(-(5 + shadowDepth * 0.6),
                          8 + shadowDepth * 0.9),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: 0.12 * shadowDepth / _kMaxShadowCards),
                      blurRadius: 28 + shadowDepth * 3,
                      offset: Offset(-(10 + shadowDepth), 16 + shadowDepth),
                    ),
                  ],
                ),
              ),
            ),

          // ── Peek layers (tiny backs sticking out to the left) ─────
          for (var i = peeks; i >= 1; i--)
            Positioned(
              left: backLeft - i * peekDx,
              top: i * peekDy,
              width: backW,
              height: backH,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardSurface.withValues(
                      alpha: 0.5 + (peeks - i) * 0.07),
                  border: Border.all(
                      color: AppColors.cardBorder
                          .withValues(alpha: 0.55 + (peeks - i) * 0.1),
                      width: 0.5),
                ),
              ),
            ),

          // ── Top discard card (face-down, small perspective back) ──
          Positioned(
            left: backLeft,
            top: 0,
            child: _CardBack(
              stackColor: topColor,
              cardW: backW,
              scale: scale * kDiscardPileScale,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card back ─────────────────────────────────────────────────────────────────

class _CardBack extends StatelessWidget {
  const _CardBack({required this.stackColor, required this.cardW, this.scale = 1.0});
  final Color stackColor;
  final double cardW;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardW,
      height: _kCardBackH * scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 3, color: stackColor.withValues(alpha: 0.7)),
              Expanded(
                child: Center(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Text(
                      'BACK',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary.withValues(alpha: 0.07),
                        letterSpacing: 10,
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

class _RuledLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFCFDFE8)
      ..strokeWidth = 0.6;
    var y = 26.0;
    while (y < size.height) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), p);
      y += 26.0;
    }
  }

  @override
  bool shouldRepaint(_RuledLinePainter old) => false;
}

// ── Nav arrow button ──────────────────────────────────────────────────────────

class _NavBtn extends StatefulWidget {
  const _NavBtn({required this.icon, required this.enabled, required this.onTap});
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTapDown: widget.enabled
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.enabled
            ? (_) => setState(() => _pressed = false)
            : null,
        onTapCancel: widget.enabled
            ? () => setState(() => _pressed = false)
            : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: _kNavBtnSize,
            height: _kNavBtnSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(
                  alpha: widget.enabled ? 0.18 : 0.06),
            ),
            child: Icon(
              widget.icon,
              size: 28,
              color: Colors.white.withValues(
                  alpha: widget.enabled ? 0.88 : 0.22),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Jump-to-first/last button ─────────────────────────────────────────────────

class _JumpBtn extends StatefulWidget {
  const _JumpBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_JumpBtn> createState() => _JumpBtnState();
}

class _JumpBtnState extends State<_JumpBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor:
            widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hovered && widget.enabled
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: Colors.white.withValues(
                  alpha: widget.enabled ? 0.55 : 0.18),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dot position indicator ────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator(
      {required this.total, required this.current, required this.onTap});
  final int total;
  final int current;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    // Show at most 15 dots; compress larger decks.
    final visible = math.min(total, 15);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(visible, (i) {
        final mapped = visible == total ? i : (i * (total - 1) / (visible - 1)).round();
        final active = mapped == current;
        return GestureDetector(
          onTap: () => onTap(visible == total ? i : mapped),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: active ? _kDotSize * 1.4 : _kDotSize,
              height: active ? _kDotSize * 1.4 : _kDotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                    alpha: active ? 0.92 : 0.28),
              ),
            ),
          ),
        );
      }),
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
const _kCardW = 110.0; // card title
const _kDateW = 72.0;  // card date
const _kDueW = 72.0;   // due date
const _kWhereW = 50.0; // now / later
const _kTagW = 80.0;   // tag name
const _kStageW = 90.0; // kanban stage
const _kStatusW = 70.0; // hidden status

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
  final _scrollCtrl = ScrollController();
  // Cached so it can be used in dispose() where ref is already invalidated.
  late final StateController<String> _searchNotifier;

  @override
  void initState() {
    super.initState();
    _searchNotifier = ref.read(taskListSearchProvider.notifier);
    _searchCtrl.addListener(() => _searchNotifier.state = _searchCtrl.text);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _searchNotifier.state = ''; // clear without going through ref
    super.dispose();
  }

  static const _priVal = {'high': 2, 'normal': 1, 'low': 0};

  List<_TaskRowData> _sorted(
    List<_TaskRowData> rows,
    TaskSortConfig cfg,
    Map<String, String> tagNames,
    Map<String, int> stageOrders,
  ) {
    if (!cfg.isSorted) return rows; // natural DB order
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
      case TaskListColumn.tag:
        result.sort((a, b) => dir(
            (tagNames[a.task.id] ?? '').compareTo(tagNames[b.task.id] ?? '')));
      case TaskListColumn.stage:
        result.sort((a, b) => dir(
            (stageOrders[a.task.kanbanStageId] ?? 999)
                .compareTo(stageOrders[b.task.kanbanStageId] ?? 999)));
      case null:
        break;
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
    final tagNames = ref.watch(taskTagNamesProvider).valueOrNull ?? {};
    final columns = ref.watch(boardColumnsProvider).valueOrNull ?? [];
    final stageOrders = {for (final c in columns) c.id: c.sortOrder};

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

    rows = _sorted(rows, sortCfg, tagNames, stageOrders);

    return ColoredBox(
      color: AppColors.cardSurface,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Search + toggle bar ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape): () {
                      _searchCtrl.clear();
                      FocusScope.of(context).unfocus();
                    },
                  },
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
                ), // CallbackShortcuts
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
                  controller: _scrollCtrl,
                  child: ListView.separated(
                    controller: _scrollCtrl,
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
      ), // Column
    ); // ColoredBox
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
          _ColHead('Tag', TaskListColumn.tag, sort, onSort, width: _kTagW),
          _ColHead('Stage', TaskListColumn.stage, sort, onSort, width: _kStageW),
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

    final tagsAsync = ref.watch(tagsForTaskProvider(task.id));
    final tags = tagsAsync.valueOrNull ?? [];
    final tagName = tags.isNotEmpty ? tags.first.name : null;

    final columns = ref.watch(boardColumnsProvider).valueOrNull ?? [];
    String? stageName;
    for (final c in columns) {
      if (c.id == task.kanbanStageId) { stageName = c.title; break; }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () =>
            ref.read(selectedTaskIdProvider.notifier).select(task.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _hovered
              ? AppColors.divider
              : Colors.transparent,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox
              SizedBox(
                width: _kCbW,
                child: Center(
                  child: GestureDetector(
                    onTap: _toggle,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
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

              // Tag name
              SizedBox(
                width: _kTagW,
                child: tagName != null
                    ? Text(tagName, style: metaStyle,
                        maxLines: 1, overflow: TextOverflow.ellipsis)
                    : Text('—', style: metaStyle),
              ),

              // Kanban stage
              SizedBox(
                width: _kStageW,
                child: Text(stageName ?? '—', style: metaStyle,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
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
