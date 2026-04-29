import 'package:flutter/material.dart';
import '../../widgets/placeholder_view.dart';

class KanbanView extends StatelessWidget {
  const KanbanView({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderView(
        icon: Icons.view_column_outlined,
        label: 'Kanban View',
        session: 'Session 6',
      );
}
