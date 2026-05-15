import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/database/app_database.dart';
import '../../providers/card_providers.dart';
import '../../providers/stack_providers.dart';
import '../card_view/widgets/index_card_widget.dart';

class ArchiveView extends ConsumerWidget {
  const ArchiveView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(archivedCardsProvider);
    final stacks = ref.watch(stacksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.viewPadding, 14, AppSpacing.viewPadding, 10),
          child: Row(
            children: [
              Text(
                'ARCHIVE',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(width: 6),
              cardsAsync.maybeWhen(
                data: (cards) => Text(
                  '${cards.length}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppColors.accentMuted),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        Expanded(
          child: cardsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (cards) {
              if (cards.isEmpty) return const _EmptyArchive();

              final stackMap = stacks.maybeWhen(
                data: (list) =>
                    <String, AppStack>{for (final s in list) s.id: s},
                orElse: () => <String, AppStack>{},
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.viewPadding,
                  0,
                  AppSpacing.viewPadding,
                  AppSpacing.viewPadding,
                ),
                child: Wrap(
                  spacing: AppSpacing.cardGap,
                  runSpacing: AppSpacing.cardGap,
                  children: cards.map((card) {
                    final stack = stackMap[card.stackId];
                    final stackColor = stack != null
                        ? Color(stack.color)
                        : AppColors.accent;
                    return IndexCardWidget(
                      key: ValueKey(card.id),
                      card: card,
                      stackColor: stackColor,
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.archive_outlined,
              size: 36, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            'Archive is empty',
            style: GoogleFonts.caveat(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Right-click a card and choose Archive to move it here.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}
