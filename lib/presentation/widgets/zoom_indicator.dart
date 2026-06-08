import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../providers/zoom_providers.dart' show kDefaultZoom;

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

// ── ZoomIndicator — interactive bottom pill ───────────────────────────────────
// Always visible at the bottom of the zoomable view. − and + buttons step zoom.

class ZoomIndicator extends StatelessWidget {
  const ZoomIndicator({
    super.key,
    required this.scale,
    this.onZoomIn,
    this.onZoomOut,
  });

  final double scale;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  @override
  Widget build(BuildContext context) {
    final pct = (scale * 100).round();

    return Container(
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillBtn(icon: Icons.remove, onTap: onZoomOut),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
          _PillBtn(icon: Icons.add, onTap: onZoomIn),
        ],
      ),
    );
  }
}

// ── Button inside the pill ────────────────────────────────────────────────────

class _PillBtn extends StatefulWidget {
  const _PillBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_PillBtn> createState() => _PillBtnState();
}

class _PillBtnState extends State<_PillBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor:
          enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hovered && enabled
                ? AppColors.divider
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: enabled
                ? AppColors.textSecondary
                : AppColors.textDisabled,
          ),
        ),
      ),
    );
  }
}
