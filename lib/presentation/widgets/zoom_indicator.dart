import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../providers/zoom_providers.dart';

// ── CardZoomData — InheritedWidget ────────────────────────────────────────────
// Carries the current animated zoom scale through the card widget tree.
// Widgets that scale their physical dimensions read CardZoomData.of(context).
// Falls back to kDefaultZoom when no ancestor is present.

class CardZoomData extends InheritedWidget {
  const CardZoomData({super.key, required this.scale, required super.child});
  final double scale;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardZoomData>()?.scale ??
      kDefaultZoom;

  @override
  bool updateShouldNotify(CardZoomData old) => old.scale != scale;
}

// ── ZoomIndicator — floating pill ─────────────────────────────────────────────
// Shown centred at the top of the card content area whenever the zoom level
// changes via a user interaction. Auto-fades after kZoomIndicatorMs ms.
// Does NOT appear on app launch or when the saved zoom is silently restored.

class ZoomIndicator extends ConsumerStatefulWidget {
  const ZoomIndicator({super.key});

  @override
  ConsumerState<ZoomIndicator> createState() => _ZoomIndicatorState();
}

class _ZoomIndicatorState extends ConsumerState<ZoomIndicator> {
  Timer? _hideTimer;
  bool _visible = false;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _show() {
    _hideTimer?.cancel();
    setState(() => _visible = true);
    _hideTimer = Timer(
      const Duration(milliseconds: kZoomIndicatorMs),
      () { if (mounted) setState(() => _visible = false); },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fires whenever the user interacts with zoom (not on silent restore).
    ref.listen(zoomInteractionProvider, (_, _next) => _show());

    final scale = ref.watch(cardZoomProvider);
    final pct = (scale * 100).round();

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            '$pct%',
            style: GoogleFonts.lato(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
