import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/app_constants.dart';
import 'database_provider.dart';

part 'zoom_providers.g.dart';

// ── Zoom constants (all named — no magic numbers) ─────────────────────────────

const kDefaultZoom         = 1.00;
const kMinZoom             = 0.60;
const kMaxZoom             = 2.00;
const kZoomSteps           = [0.60, 0.75, 1.00, 1.25, 1.50, 1.75, 2.00];
const kZoomSpringMass      = 1.0;
const kZoomSpringStiffness = 320.0;
const kZoomSpringDamping   = 28.0;
const kZoomIndicatorMs     = 1200; // fade-out delay after last zoom interaction

// ── Interaction counter ───────────────────────────────────────────────────────
// Incremented on every user-triggered zoom event. The zoom indicator widget
// watches this; the notifier does NOT increment during preference restore, so
// the indicator stays hidden on launch.
final zoomInteractionProvider = StateProvider<int>((ref) => 0);

// ── Notifier ──────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
class CardZoom extends _$CardZoom {
  @override
  double build() {
    // Restore persisted value asynchronously. Returns the default synchronously
    // so first frame renders at 1.0; updates one microtask later.
    Future.microtask(_restore);
    return kDefaultZoom;
  }

  Future<void> _restore() async {
    final stored =
        await ref.read(settingsDaoProvider).get(AppConstants.kCardZoomScale);
    if (stored == null) return;
    final parsed = double.tryParse(stored);
    if (parsed != null) {
      // Set state directly — does NOT increment zoomInteractionProvider.
      state = parsed.clamp(kMinZoom, kMaxZoom);
    }
  }

  void zoomIn() {
    final next = _stepUp(state);
    _set(next);
  }

  void zoomOut() {
    final next = _stepDown(state);
    _set(next);
  }

  void reset() => _set(kDefaultZoom);

  /// Called continuously during a pinch gesture — no step snapping, no persist.
  /// The caller is responsible for calling [snapToNearestStep] on gesture end.
  void setFromGesture(double rawScale) {
    state = clampDouble(rawScale, kMinZoom, kMaxZoom);
    ref.read(zoomInteractionProvider.notifier).update((n) => n + 1);
  }

  /// Snap the current continuous value to the nearest defined step and persist.
  void snapToNearestStep() {
    final snapped = _nearestStep(state);
    state = snapped;
    _persist(snapped);
    ref.read(zoomInteractionProvider.notifier).update((n) => n + 1);
  }

  void _set(double value) {
    state = clampDouble(value, kMinZoom, kMaxZoom);
    _persist(state);
    ref.read(zoomInteractionProvider.notifier).update((n) => n + 1);
  }

  void _persist(double scale) {
    ref.read(settingsDaoProvider).set(AppConstants.kCardZoomScale, scale.toString());
  }

  double _stepUp(double current) {
    for (final step in kZoomSteps) {
      if (step > current + 0.01) return step;
    }
    return kMaxZoom;
  }

  double _stepDown(double current) {
    for (final step in kZoomSteps.reversed) {
      if (step < current - 0.01) return step;
    }
    return kMinZoom;
  }

  static double _nearestStep(double current) =>
      kZoomSteps.reduce((a, b) =>
          (a - current).abs() <= (b - current).abs() ? a : b);
}
