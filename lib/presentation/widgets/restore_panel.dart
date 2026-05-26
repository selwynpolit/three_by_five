import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/theme/app_colors.dart';
import '../providers/backup_providers.dart';

class RestorePanelOverlay extends ConsumerWidget {
  const RestorePanelOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restoreNotifierProvider);
    // ESC is disabled during atomic swap and on the done screen
    final canEscape = !state.noCancel &&
        state.phase != RestorePhase.done &&
        state.phase != RestorePhase.running;

    return CallbackShortcuts(
      bindings: {
        if (canEscape)
          const SingleActivator(LogicalKeyboardKey.escape): () {
            ref.read(restoreNotifierProvider.notifier).reset();
            ref.read(restorePanelVisibleProvider.notifier).state = false;
          },
      },
      child: Focus(
        autofocus: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Backdrop tap closes only when not in progress
          onTap: canEscape
              ? () {
                  ref.read(restoreNotifierProvider.notifier).reset();
                  ref.read(restorePanelVisibleProvider.notifier).state = false;
                }
              : null,
          child: Container(
            color: Colors.black.withValues(alpha: 0.50),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // swallow taps inside card
                child: const _RestoreCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RestoreCard extends ConsumerWidget {
  const _RestoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restoreNotifierProvider);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: switch (state.phase) {
              RestorePhase.idle      => _IdleBody(),
              RestorePhase.reading   => _ReadingBody(),
              RestorePhase.preview   => _PreviewBody(state: state),
              RestorePhase.running   => _RunningBody(state: state),
              RestorePhase.done      => _DoneBody(state: state),
              RestorePhase.failed    => _FailedBody(state: state),
              RestorePhase.cancelled => _CancelledBody(),
            },
          ),
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
          const Icon(Icons.restore_outlined, size: 20, color: AppColors.accent),
          const SizedBox(width: 8),
          _H('Restore from Backup'),
        ]),
        const SizedBox(height: 10),
        _Body('Select a .3by5backup file to restore from. '
            'A safety backup of your current data will be created '
            'automatically before anything is changed.'),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _Ghost('Cancel', () {
              ref.read(restoreNotifierProvider.notifier).reset();
              ref.read(restorePanelVisibleProvider.notifier).state = false;
            }),
            const SizedBox(width: 10),
            _Primary('Choose Backup File…', Icons.folder_open_outlined, () {
              ref.read(restoreNotifierProvider.notifier).pickAndReadManifest();
            }),
          ],
        ),
      ],
    );
  }
}

// ── Reading ───────────────────────────────────────────────────────────────────

class _ReadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        const CircularProgressIndicator(strokeWidth: 2),
        const SizedBox(height: 16),
        Text('Reading backup file…',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ── Preview ───────────────────────────────────────────────────────────────────

class _PreviewBody extends ConsumerWidget {
  const _PreviewBody({required this.state});
  final RestoreState state;

  static final _dtFmt = intl.DateFormat("EEE d MMM yyyy 'at' HH:mm");

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = state.manifest!;
    final isOlder = m.formatVersion < 1; // can't happen yet but future-proof

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.restore_outlined, size: 20, color: AppColors.accent),
            const SizedBox(width: 8),
            _H('Restore from Backup'),
          ]),
          const SizedBox(height: 16),

          // Backup summary card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow('Backup created',
                    _dtFmt.format(m.createdAt.toLocal())),
                _InfoRow('App version', m.appVersion),
                if (m.deviceName.isNotEmpty)
                  _InfoRow('Device', m.deviceName),
                _InfoRow('Backup type',
                    m.backupType[0].toUpperCase() + m.backupType.substring(1)),
                const Divider(height: 18, thickness: 0.5),
                _InfoRow('Stacks',
                    '${m.recordCounts['stacks'] ?? '—'}'),
                _InfoRow('Cards', '${m.recordCounts['cards'] ?? '—'}'),
                _InfoRow('Tasks', '${m.recordCounts['tasks'] ?? '—'}'),
                _InfoRow('Notes', '${m.recordCounts['notes'] ?? '—'}'),
                _InfoRow('Attachments',
                    '${m.recordCounts['attachments'] ?? '—'}'),
              ],
            ),
          ),

          if (isOlder) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.dueTodayBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 15, color: AppColors.dueTodayText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This backup was created by an older version of 3by5. '
                      'It should restore correctly.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.dueTodayText,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.overdueBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    size: 15, color: AppColors.overdueText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current app data will be replaced. '
                    'A safety backup will be created automatically first.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.overdueText,
                        ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _Ghost('Cancel', () {
                ref.read(restoreNotifierProvider.notifier).reset();
                ref.read(restorePanelVisibleProvider.notifier).state = false;
              }),
              const SizedBox(width: 10),
              _DestructiveBtn('Replace My Data', () {
                ref.read(restoreNotifierProvider.notifier).startRestore();
              }),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Running ───────────────────────────────────────────────────────────────────

class _RunningBody extends ConsumerWidget {
  const _RunningBody({required this.state});
  final RestoreState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _H('Restoring from Backup…'),
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
        if (state.safetyBackupPath != null) ...[
          const SizedBox(height: 6),
          Text(
            '✓ Safety backup saved',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!state.noCancel)
              _Ghost('Cancel', () {
                ref.read(restoreNotifierProvider.notifier).cancel();
              })
            else
              Text(
                'Please wait — do not close the app.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Done (with countdown) ─────────────────────────────────────────────────────

class _DoneBody extends ConsumerStatefulWidget {
  const _DoneBody({required this.state});
  final RestoreState state;

  @override
  ConsumerState<_DoneBody> createState() => _DoneBodyState();
}

class _DoneBodyState extends ConsumerState<_DoneBody> {
  int _countdown = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        exit(0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.state.result;
    final m = widget.state.manifest;
    final safetyPath = widget.state.safetyBackupPath;
    final dtFmt = intl.DateFormat("EEE d MMM yyyy 'at' HH:mm");

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.check_circle_outline,
              size: 20, color: AppColors.accent),
          const SizedBox(width: 8),
          _H('Restore complete'),
        ]),
        const SizedBox(height: 14),
        if (m != null)
          _Body('Your 3by5 data has been restored from the backup '
              'created on ${dtFmt.format(m.createdAt.toLocal())}.'),
        const SizedBox(height: 12),
        if (result != null) ...[
          _SummaryRow2('Stacks restored', '${result.stackCount}'),
          _SummaryRow2('Cards restored', '${result.cardCount}'),
          _SummaryRow2('Tasks restored', '${result.taskCount}'),
          _SummaryRow2('Attachments', '${result.attachmentCount}'),
        ],
        if (safetyPath != null) ...[
          const SizedBox(height: 12),
          _Body('Safety backup of your previous data was saved to:'),
          const SizedBox(height: 4),
          Text(
            safetyPath,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Restarting 3by5 to complete the restore… ($_countdown)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ── Failed ────────────────────────────────────────────────────────────────────

class _FailedBody extends ConsumerWidget {
  const _FailedBody({required this.state});
  final RestoreState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.error_outline,
              size: 20, color: AppColors.overdueText),
          const SizedBox(width: 8),
          _H('Restore failed'),
        ]),
        const SizedBox(height: 10),
        _Body('Your data has not been changed.'),
        if (state.error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.overdueBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(state.error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.overdueText,
                    )),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _Ghost('Try again', () {
              ref.read(restoreNotifierProvider.notifier).reset();
            }),
            const SizedBox(width: 10),
            _Primary('Close', null, () {
              ref.read(restoreNotifierProvider.notifier).reset();
              ref.read(restorePanelVisibleProvider.notifier).state = false;
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
        _H('Restore cancelled'),
        const SizedBox(height: 8),
        _Body('Your data has not been changed.'),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _Primary('Close', null, () {
              ref.read(restoreNotifierProvider.notifier).reset();
              ref.read(restorePanelVisibleProvider.notifier).state = false;
            }),
          ],
        ),
      ],
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600, color: AppColors.textPrimary));
}

class _Body extends StatelessWidget {
  const _Body(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: AppColors.textSecondary));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow2 extends StatelessWidget {
  const _SummaryRow2(this.label, this.value);
  final String label;
  final String value;

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
                    color: AppColors.textPrimary,
                  )),
        ],
      ),
    );
  }
}

class _Primary extends StatelessWidget {
  const _Primary(this.label, this.icon, this.onTap);
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

class _DestructiveBtn extends StatefulWidget {
  const _DestructiveBtn(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  State<_DestructiveBtn> createState() => _DestructiveBtnState();
}

class _DestructiveBtnState extends State<_DestructiveBtn> {
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
            color: _hovered
                ? AppColors.priorityHigh
                : AppColors.priorityHigh.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(widget.label,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _Ghost extends StatefulWidget {
  const _Ghost(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  State<_Ghost> createState() => _GhostState();
}

class _GhostState extends State<_Ghost> {
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
