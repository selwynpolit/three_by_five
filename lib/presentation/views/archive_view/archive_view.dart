import 'package:flutter/material.dart';
import '../../widgets/placeholder_view.dart';

class ArchiveView extends StatelessWidget {
  const ArchiveView({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderView(
        icon: Icons.archive_outlined,
        label: 'Archive',
        session: 'Session 8',
      );
}
