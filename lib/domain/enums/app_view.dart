enum AppView {
  cardView,
  kanbanView,
  calendarView,
  todayView,
  archiveView,
  allCardsView;

  /// Keyboard shortcut index (⌘1 … ⌘5 for the five nav views).
  int get shortcutIndex => index + 1;

  static AppView? fromShortcutIndex(int n) =>
      n >= 1 && n <= 5 ? AppView.values[n - 1] : null;
}
