import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums/app_view.dart';
import '../providers/zoom_providers.dart';
import 'zoom_indicator.dart';

// ── ZoomedViewArea ────────────────────────────────────────────────────────────
// Wraps any view that supports zoom. Captures trackpad pinch and ⌘+scroll,
// runs a spring animation, propagates the animated scale via CardZoomData and
// MediaQuery.textScaler, and shows the ZoomIndicator pill.

class ZoomedViewArea extends ConsumerStatefulWidget {
  const ZoomedViewArea({super.key, required this.view, required this.child});
  final AppView view;
  final Widget child;

  @override
  ConsumerState<ZoomedViewArea> createState() => _ZoomedViewAreaState();
}

class _ZoomedViewAreaState extends ConsumerState<ZoomedViewArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _gestureActive = false;
  double _startGestureScale = kDefaultZoom;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      lowerBound: kMinZoom,
      upperBound: kMaxZoom,
      value: kDefaultZoom,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    final clamped = target.clamp(kMinZoom, kMaxZoom);
    _ctrl.animateWith(SpringSimulation(
      const SpringDescription(
        mass: kZoomSpringMass,
        stiffness: kZoomSpringStiffness,
        damping: kZoomSpringDamping,
      ),
      _ctrl.value,
      clamped,
      0,
    ));
  }

  void _onPanZoomStart(PointerPanZoomStartEvent _) {
    _gestureActive = true;
    _startGestureScale = _ctrl.value;
    _ctrl.stop();
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent ev) {
    if (!_gestureActive) return;
    final raw = _startGestureScale * ev.scale;
    _ctrl.value = raw.clamp(kMinZoom, kMaxZoom);
    ref.read(viewZoomProvider(widget.view).notifier).setFromGesture(_ctrl.value);
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent _) {
    _gestureActive = false;
    ref.read(viewZoomProvider(widget.view).notifier).snapToNearestStep();
    _animateTo(ref.read(viewZoomProvider(widget.view)));
  }

  void _onPointerSignal(PointerSignalEvent ev) {
    if (ev is! PointerScrollEvent) return;
    if (!HardwareKeyboard.instance.isMetaPressed) return;
    if (ev.scrollDelta.dy > 0) {
      ref.read(viewZoomProvider(widget.view).notifier).zoomOut();
    } else if (ev.scrollDelta.dy < 0) {
      ref.read(viewZoomProvider(widget.view).notifier).zoomIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(viewZoomProvider(widget.view), (_, next) {
      if (_gestureActive) return;
      _animateTo(next);
    });

    return Listener(
      onPointerSignal: _onPointerSignal,
      onPointerPanZoomStart: _onPanZoomStart,
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      onPointerPanZoomEnd: _onPanZoomEnd,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) => Stack(
          fit: StackFit.expand,
          children: [
            MediaQuery(
              data: MediaQuery.of(ctx).copyWith(
                textScaler: TextScaler.linear(_ctrl.value),
              ),
              child: CardZoomData(scale: _ctrl.value, child: child!),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: ZoomIndicator(),
              ),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
