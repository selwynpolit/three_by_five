abstract final class AppSpacing {
  // ── Base scale ───────────────────────────────────────────────────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // ── Layout ──────────────────────────────────────────────────────────────────
  static const double sidebarWidth = 220;
  static const double viewPadding = 32;

  // ── Card ────────────────────────────────────────────────────────────────────
  static const double cardWidth = 520;
  static const double cardPadding = 14;
  static const double cardHeaderHeight = 54;
  static const double cardRadius = 10;
  static const double cardGap = 22;

  // ── Task row ────────────────────────────────────────────────────────────────
  static const double taskRowMinHeight = 34;
  static const double checkboxSize = 18;
  static const double columnHeaderHeight = 26;

  // ── Borders ──────────────────────────────────────────────────────────────────
  /// Standard hairline border / divider thickness.
  static const double hairline = 0.5;

  // ── Context menu (right-click popup) ─────────────────────────────────────────
  static const double contextMenuItemHeight = 32;
  static const double contextMenuItemHPad = 14;

  // ── Zoom-scaling anchors (multiply by zoom scale factor) ─────────────────────
  /// Fixed height of each task row cell in the card column.
  static const double taskRowHeight = 22.0;
  /// Height of one task slot (row + inactive drop zone = 26px).
  static const double taskCellHeight = 26.0;
  /// Total fixed slot area for 6 task rows (6 × taskCellHeight).
  static const double taskRowSlotHeight = 156.0;
  /// Height of the "Add Now / Add Later" bar at the card bottom.
  static const double addTaskBarHeight = 26.0;
}
