import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/database/app_database.dart';

class NotesFeedWidget extends StatelessWidget {
  const NotesFeedWidget({super.key, required this.notesAsync});
  final AsyncValue<List<AppNote>> notesAsync;

  @override
  Widget build(BuildContext context) {
    return notesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (notes) {
        if (notes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No notes yet. Add one below.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textDisabled,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: notes
              .map((note) => _NoteItem(note: note))
              .toList(),
        );
      },
    );
  }
}

class _NoteItem extends StatelessWidget {
  const _NoteItem({required this.note});
  final AppNote note;

  static final _timeFmt = DateFormat('d MMM yyyy · h:mm a');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            _timeFmt.format(note.createdAt),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w400,
                ),
          ),
          const SizedBox(height: 3),
          // Body
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.divider, width: 0.5),
            ),
            child: Text(
              note.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
