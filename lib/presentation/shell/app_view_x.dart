import 'package:flutter/material.dart';
import '../../domain/enums/app_view.dart';

extension AppViewPresentation on AppView {
  IconData get icon => switch (this) {
        AppView.cardView || AppView.allCardsView => Icons.style_outlined,
        AppView.kanbanView => Icons.view_column_outlined,
        AppView.calendarView => Icons.calendar_month_outlined,
        AppView.todayView => Icons.wb_sunny_outlined,
        AppView.archiveView => Icons.archive_outlined,
      };

  String get label => switch (this) {
        AppView.cardView => 'Cards',
        AppView.kanbanView => 'Kanban',
        AppView.calendarView => 'Calendar',
        AppView.todayView => 'Today',
        AppView.archiveView => 'Archive',
        AppView.allCardsView => 'All Cards',
      };
}
