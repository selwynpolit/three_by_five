import 'package:flutter/material.dart';
import '../../widgets/placeholder_view.dart';

class TodayView extends StatelessWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderView(
        icon: Icons.wb_sunny_outlined,
        label: 'Today Dashboard',
        session: 'Session 8',
      );
}
