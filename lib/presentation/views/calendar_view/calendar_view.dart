import 'package:flutter/material.dart';
import '../../widgets/placeholder_view.dart';

class CalendarView extends StatelessWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderView(
        icon: Icons.calendar_month_outlined,
        label: 'Calendar View',
        session: 'Session 7',
      );
}
