import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../providers/export_providers.dart';

class ExportPanelOverlay extends ConsumerWidget {
  const ExportPanelOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          final phase = ref.read(exportNotifierProvider).phase;
          if (phase != ExportPhase.running) {
            ref.read(exportNotifierProvider.notifier).reset();
            ref.read(exportPanelVisibleProvider.notifier).state = false;
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(child: _ExportCard()),
        ),
      ),
    );
  }
}

class _ExportCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exportNotifierProvider);
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
            ExportPhase.idle     => _IdleBody(),
            ExportPhase.running  => _RunningBody(state: state),
            ExportPhase.done     => _DoneBody(state: state),
            ExportPhase.empty    => _EmptyBody(),
            ExportPhase.failed   => _FailedBody(state: state),
            ExportPhase.cancelled => _CancelledBody(),
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
        _Title('Export Data'),
        const SizedBox(height: 10),
        Text(
          'Exports all your tasks, notes, and attachments as a zip file '
          'you can open in Excel or Numbers.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CancelBtn('Cancel', () {
              ref.read(exportPanelVisibleProvider.notifier).state = false;
            }),
            const SizedBox(width: 10),
            _PrimaryBtn('Export', Icons.download_outlined, () {
              ref.read(exportNotifierProvider.notifier).startExport();
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
  final ExportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title('Exporting…'),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: state.fraction,
            minHeight: 6,
            backgroundColor: AppColors.divider,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          state.status,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CancelBtn('Cancel', () {
              ref.read(exportNotifierProvider.notifier).cancel();
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
  final ExportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = state.result!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_outline,
                size: 20, color: AppColors.accent),
            const SizedBox(width: 8),
            _Title('Export complete'),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryRow('Tasks exported', '${result.taskCount}'),
        _SummaryRow('Attachments', '${result.attachmentCount}'),
        if (result.missingFileCount > 0)
          _SummaryRow(
            'Missing files',
            '${result.missingFileCount}',
            color: AppColors.overdueText,
          ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CancelBtn('Show in Finder', () async {
              await Process.run('open', ['-R', result.outputPath]);
            }),
            const SizedBox(width: 10),
            _PrimaryBtn('Done', null, () {
              ref.read(exportNotifierProvider.notifier).reset();
              ref.read(exportPanelVisibleProvider.notifier).state = false;
            }),
          ],
        ),
      ],
    );
  }
}

// ── Empty ─────────────────────────────────────────────────────────────────────

class _EmptyBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title('Nothing to export yet'),
        const SizedBox(height: 10),
        Text(
          'Add some tasks first, then come back here to export them.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: _PrimaryBtn('Close', null, () {
            ref.read(exportNotifierProvider.notifier).reset();
            ref.read(exportPanelVisibleProvider.notifier).state = false;
          }),
        ),
      ],
    );
  }
}

// ── Failed ────────────────────────────────────────────────────────────────────

class _FailedBody extends ConsumerWidget {
  const _FailedBody({required this.state});
  final ExportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline,
                size: 20, color: AppColors.overdueText),
            const SizedBox(width: 8),
            _Title('Export failed'),
          ],
        ),
        const SizedBox(height: 10),
        if (state.error != null)
          Text(
            state.error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace',
                ),
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CancelBtn('Try again', () {
              ref.read(exportNotifierProvider.notifier).startExport();
            }),
            const SizedBox(width: 10),
            _PrimaryBtn('Close', null, () {
              ref.read(exportNotifierProvider.notifier).reset();
              ref.read(exportPanelVisibleProvider.notifier).state = false;
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
        _Title('Export cancelled'),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CancelBtn('Export again', () {
              ref.read(exportNotifierProvider.notifier).startExport();
            }),
            const SizedBox(width: 10),
            _PrimaryBtn('Close', null, () {
              ref.read(exportNotifierProvider.notifier).reset();
              ref.read(exportPanelVisibleProvider.notifier).state = false;
            }),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
      );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color ?? AppColors.textPrimary,
                ),
          ),
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

class _CancelBtn extends StatefulWidget {
  const _CancelBtn(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  State<_CancelBtn> createState() => _CancelBtnState();
}

class _CancelBtnState extends State<_CancelBtn> {
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
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
