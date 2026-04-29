import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/database/app_database.dart';
import '../../providers/card_providers.dart';
import '../../providers/stack_providers.dart';
import 'widgets/index_card_widget.dart';

class CardView extends ConsumerWidget {
  const CardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsProvider);
    final stacks = ref.watch(stacksProvider);

    return cardsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (cards) {
        if (cards.isEmpty) {
          return const _EmptyState();
        }

        // Build a quick lookup map: stackId → stack (for color tinting)
        final stackMap = stacks.maybeWhen(
          data: (list) =>
              <String, AppStack>{for (final s in list) s.id: s},
          orElse: () => <String, AppStack>{},
        );

        return Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.viewPadding),
            child: Wrap(
              spacing: AppSpacing.cardGap,
              runSpacing: AppSpacing.cardGap,
              children: cards
                  .map((card) => IndexCardWidget(
                        card: card,
                        stackColor: stackMap[card.stackId] != null
                            ? Color(stackMap[card.stackId]!.color)
                            : AppColors.accent,
                      ))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No cards here yet',
            style: GoogleFonts.caveat(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Press ⌘N to add your first task',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
