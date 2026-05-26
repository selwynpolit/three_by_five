import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/theme/app_colors.dart';
import '../providers/backup_providers.dart';

class BackupPanelOverlay extends ConsumerWidget {
  const BackupPanelOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(backupNotifierProvider).phase;
    final canEscape = phase != BackupPhase.running;

    return CallbackShortcuts(
      bindings: {
        if (canEscape)
          const SingleActivator(LogicalKeyboardKey.escape): () {
            ref.read(backupNotifierProvider.notifier).reset();
            ref.read(backupPanelVisibleProvider.notifier).state = false;
          },
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(child: _BackupCard()),
        ),
      ),
    );
  }
}

class _BackupCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupNotifierProvider);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: switch (state.phase) {
            BackupPhase.idle     => _IdleBody(),
            BackupPhase.running  => _RunningBody(state: state),
            BackupPhase.done     => _DoneBody(state: state),
            BackupPhase.failed   => _FailedBody(state: state),
            BackupPhase.cancelled => _CancelledBody(),
          },
        ),
      ),
    );
  }
}

// ── Idle ──────────────────────────────────────────────────────────────────────

class _IdleBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.backup_outlined, size: 20, color: AppColors.accent),
          const SizedBox(width: 8),
          _Title('Create Backup'),
        ]),
        const SizedBox(height: 10),
        Text(
          'Saves a complete copy of all your tasks, notes, and '
          'attachments as a single .3by5backup file.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _GhostBtn('Cancel', () {
              ref.read(backupPanelVisibleProvider.notifier).state = false;
            }),
            const SizedBox(width: 10),
            _PrimaryBtn('Create Backup', Icons.backup_outlined, () {
              ref.read(backupNotifierProvider.notifier).startBackup();
            }),
          ],
        ),
      ],
    );
  }
}

// ── Running ───────────────────────────────────────────────────────────────────

class _RunningBody extends ConsumerWidget {
  const _RunningBody({required this.state});
  final BackupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title('Creating Backup…'),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: state.fraction > 0 ? state.fraction : null,
            minHeight: 6,
            backgroundColor: AppColors.divider,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
        const SizedBox(height: 10),
        Text(state.status,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _GhostBtn('Cancel', () {
              ref.read(backupNotifierProvider.notifier).cancel();
            }),
          ],
        ),
      ],
    );
  }
}

// ── Done ──────────────────────────────────────────────────────────────────────

class _DoneBody extends ConsumerWidget {
  const _DoneBody({required this.state});
  final BackupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = state.result;
    final dateFmt = intl.DateFormat('EEE d MMM yyyy');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.check_circle_outline,
              size: 20, color: AppColors.accent),
          const SizedBox(width: 8),
          _Title('Backup complete'),
        ]),
        const SizedBox(height: 14),
        if (result != null) ...[
          _SummaryRow('Tasks', '${result.taskCount}'),
          _SummaryRow('Cards', '${result.cardCount}'),
          _SummaryRow('Stacks', '${result.stackCount}'),
          _SummaryRow('Image attachments', '${result.attachmentCount}'),
          const SizedBox(height: 8),
          Text(
            'Saved to: ${result.outputPath}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _GhostBtn('Show in Finder', () async {
              if (result != null) {
                await Process.run('open', ['-R', result.outputPath]);
              }
            }),
            const SizedBox(width: 10),
            _PrimaryBtn('Done', null, () {
              ref.read(backupNotifierProvider.notifier).reset();
              ref.read(backupPanelVisibleProvider.notifier).state = false;
            }),
          ],
        ),
      ],
    );
  }
}

// ── Failed ────────────────────────────────────────────────────────────────────

class _FailedBody extends ConsumerWidget {
  const _FailedBody({required this.state});
  final BackupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.error_outline, size: 20, color: AppColors.overdueText),
          const SizedBox(width: 8),
          _Title('Backup failed'),
        ]),
        const SizedBox(height: 10),
        if (state.error != null)
          Text(state.error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  )),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _GhostBtn('Try again', () {
              ref.read(backupNotifierProvider.notifier).startBackup();
            }),
            const SizedBox(width: 10),
            _PrimaryBtn('Close', null, () {
              ref.read(backupNotifierProvider.notifier).reset();
              ref.read(backupPanelVisibleProvider.notifier).state = false;
            }),
          ],
        ),
      ],
    );
  }
}

// ── Cancelled ─────────────────────────────────────────────────────────────────

class _CancelledBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title('Backup cancelled'),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _GhostBtn('Back up now', () {
              ref.read(backupNotifierProvider.notifier).startBackup();
            }),
            const SizedBox(width: 10),
            _PrimaryBtn('Close', null, () {
              ref.read(backupNotifierProvider.notifier).reset();
              ref.read(backupPanelVisibleProvider.notifier).state = false;
            }),
          ],
        ),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ));
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary))),
          Text(value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color ?? AppColors.textPrimary,
                  )),
        ],
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn(this.label, this.icon, this.onTap);
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostBtn extends StatefulWidget {
  const _GhostBtn(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  State<_GhostBtn> createState() => _GhostBtnState();
}

class _GhostBtnState extends State<_GhostBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.divider : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Text(widget.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  )),
        ),
      ),
    );
  }
}
