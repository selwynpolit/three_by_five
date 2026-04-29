import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PlaceholderView extends StatelessWidget {
  const PlaceholderView({
    super.key,
    required this.icon,
    required this.label,
    required this.session,
  });

  final IconData icon;
  final String label;
  final String session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: 6),
            Text(
              'Coming in $session',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textDisabled),
            ),
          ],
        ),
      ),
    );
  }
}
