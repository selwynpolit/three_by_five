import 'dart:io';

import 'package:file_picker/file_picker.dart';
import '../../core/services/backup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path/path.dart' as p;

import '../../core/theme/app_colors.dart';
import '../../data/daos/settings_dao.dart';
import '../providers/backup_providers.dart';
import '../providers/database_provider.dart';
import '../providers/export_providers.dart';

class SettingsPanelOverlay extends ConsumerWidget {
  const SettingsPanelOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            ref.read(settingsPanelVisibleProvider.notifier).state = false,
      },
      child: Focus(
        autofocus: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              ref.read(settingsPanelVisibleProvider.notifier).state = false,
          child: Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: const _SettingsCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(
                  color: AppColors.sidebarBg,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border(
                    bottom: BorderSide(
                        color: AppColors.sidebarDivider, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Settings',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                    ),
                    const Spacer(),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => ref
                            .read(settingsPanelVisibleProvider.notifier)
                            .state = false,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable body ─────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _BackupRestoreSection(),
                      const SizedBox(height: 20),
                      const _AutoBackupSection(),
                      const SizedBox(height: 20),
                      const _SafetyBackupsSection(),
                      const SizedBox(height: 20),
                      const _ExportSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Backup & Restore section ───────────────────────────────────────────────────

class _BackupRestoreSection extends ConsumerWidget {
  const _BackupRestoreSection();

  static final _dtFmt = intl.DateFormat("EEE d MMM yyyy 'at' HH:mm");

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastDate = ref.watch(lastManualBackupDateProvider).valueOrNull;
    final lastSize = ref.watch(lastManualBackupSizeProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('BACKUP & RESTORE'),
        const SizedBox(height: 12),
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
              // Last backup info
              Row(
                children: [
                  Text(
                    lastDate != null
                        ? 'Last backup: ${_dtFmt.format(lastDate.toLocal())}'
                        : 'No backup yet',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: lastDate != null
                              ? AppColors.textSecondary
                              : AppColors.textDisabled,
                        ),
                  ),
                  if (lastSize != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(${_formatBytes(lastSize)})',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _ActionBtn(
                    icon: Icons.backup_outlined,
                    label: 'Create Backup',
                    onTap: () {
                      ref.read(backupNotifierProvider.notifier).reset();
                      ref
                          .read(settingsPanelVisibleProvider.notifier)
                          .state = false;
                      ref.read(backupPanelVisibleProvider.notifier).state =
                          true;
                    },
                  ),
                  const SizedBox(width: 10),
                  _ActionBtn(
                    icon: Icons.restore_outlined,
                    label: 'Restore from Backup',
                    onTap: () {
                      ref.read(restoreNotifierProvider.notifier).reset();
                      ref
                          .read(settingsPanelVisibleProvider.notifier)
                          .state = false;
                      ref.read(restorePanelVisibleProvider.notifier).state =
                          true;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ── Automatic backups section ──────────────────────────────────────────────────

class _AutoBackupSection extends ConsumerWidget {
  const _AutoBackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frequency =
        ref.watch(autoBackupFrequencyProvider).valueOrNull ?? 'off';
    final configuredFolder =
        ref.watch(autoBackupFolderProvider).valueOrNull;
    final dao = SettingsDao(ref.watch(appDatabaseProvider));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('AUTOMATIC BACKUPS'),
        const SizedBox(height: 12),
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
              // Frequency row
              Row(
                children: [
                  Text('Frequency',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary)),
                  const Spacer(),
                  _FrequencyPicker(
                    current: frequency,
                    onChange: (v) => dao.set('backupAutoFrequency', v),
                  ),
                ],
              ),
              if (frequency != 'off') ...[
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 12),
                // Folder row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Backup folder',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<String>(
                        future: ref
                            .read(backupServiceProvider)
                            .defaultAutoBackupPath(),
                        builder: (ctx, snap) {
                          final defaultPath = snap.data ?? '…';
                          final displayPath = configuredFolder?.isNotEmpty == true &&
                                  configuredFolder != 'default'
                              ? configuredFolder!
                              : defaultPath;
                          return Text(
                            _shortenPath(displayPath),
                            style: Theme.of(ctx)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: AppColors.textTertiary,
                                    fontFamily: 'monospace',
                                    fontSize: 10),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SmallBtn('Change…', () async {
                      final chosen =
                          await FilePicker.platform.getDirectoryPath(
                        dialogTitle: 'Choose Automatic Backup Folder',
                      );
                      if (chosen != null) {
                        await dao.set('backupAutoFolder', chosen);
                      }
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Keeps the last 7 backups. Older ones are removed automatically.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textDisabled,
                        fontSize: 11,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _shortenPath(String full) {
    final home = Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty && full.startsWith(home)) {
      return '~${full.substring(home.length)}';
    }
    return full;
  }
}

// ── Safety backups section ────────────────────────────────────────────────────

class _SafetyBackupsSection extends ConsumerWidget {
  const _SafetyBackupsSection();

  static final _dtFmt = intl.DateFormat('d MMM yyyy HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safetyAsync = ref.watch(safetyBackupsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('SAFETY BACKUPS'),
        const SizedBox(height: 6),
        Text(
          'Created automatically before every restore. Never deleted automatically.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textDisabled, fontSize: 11),
        ),
        const SizedBox(height: 10),
        safetyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5))),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (records) {
            if (records.isEmpty) {
              return Text(
                'No safety backups yet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textDisabled,
                      fontStyle: FontStyle.italic,
                    ),
              );
            }
            return Column(
              children: [
                ...records.map((r) => _SafetyRow(
                      record: r,
                      dateLabel: _dtFmt.format(r.createdAt.toLocal()),
                      onDelete: () async {
                        final ok = await _confirmDelete(context);
                        if (!ok) return;
                        await ref
                            .read(backupServiceProvider)
                            .deleteSafetyBackup(file: r.file);
                        ref.invalidate(safetyBackupsProvider);
                      },
                    )),
                if (records.length > 1) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _SmallDestructiveBtn(
                      'Delete All Safety Backups',
                      () async {
                        final ok = await _confirmDeleteAll(context);
                        if (!ok) return;
                        await ref
                            .read(backupServiceProvider)
                            .deleteAllSafetyBackups();
                        ref.invalidate(safetyBackupsProvider);
                      },
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete safety backup?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.priorityHigh))),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _confirmDeleteAll(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all safety backups?'),
        content: const Text(
            'All safety backups will be permanently deleted. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.priorityHigh),
              child: const Text('Delete All')),
        ],
      ),
    );
    return result ?? false;
  }
}

class _SafetyRow extends StatefulWidget {
  const _SafetyRow({
    required this.record,
    required this.dateLabel,
    required this.onDelete,
  });

  final SafetyBackupRecord record;
  final String dateLabel;
  final VoidCallback onDelete;

  @override
  State<_SafetyRow> createState() => _SafetyRowState();
}

class _SafetyRowState extends State<_SafetyRow> {
  bool _hovered = false;

  static String _fmtBytes(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined,
                size: 13, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${widget.dateLabel}  ·  ${_fmtBytes(widget.record.sizeBytes)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary),
              ),
            ),
            AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 120),
              child: GestureDetector(
                onTap: widget.onDelete,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('Delete',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.priorityHigh)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Export section ────────────────────────────────────────────────────────────

class _ExportSection extends ConsumerWidget {
  const _ExportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('EXPORT'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.table_chart_outlined,
                    size: 18, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Export to CSV',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                        'Tasks, notes and attachments as a zip — '
                        'opens in Excel or Numbers.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ActionBtn(
                icon: Icons.download_outlined,
                label: 'Export…',
                onTap: () {
                  ref.read(exportNotifierProvider.notifier).reset();
                  ref.read(settingsPanelVisibleProvider.notifier).state = false;
                  ref.read(exportPanelVisibleProvider.notifier).state = true;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary, letterSpacing: 0.8));
}

class _FrequencyPicker extends StatelessWidget {
  const _FrequencyPicker({required this.current, required this.onChange});
  final String current;
  final void Function(String) onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ['off', 'daily', 'weekly'].map((v) {
        final isActive = current == v;
        return GestureDetector(
          onTap: () => onChange(v),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              margin: const EdgeInsets.only(left: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accent
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                v[0].toUpperCase() + v.substring(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  const _ActionBtn(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.accent : AppColors.accent.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Text(widget.label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallBtn extends StatefulWidget {
  const _SmallBtn(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  State<_SmallBtn> createState() => _SmallBtnState();
}

class _SmallBtnState extends State<_SmallBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.divider : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Text(widget.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}

class _SmallDestructiveBtn extends StatefulWidget {
  const _SmallDestructiveBtn(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  State<_SmallDestructiveBtn> createState() => _SmallDestructiveBtnState();
}

class _SmallDestructiveBtnState extends State<_SmallDestructiveBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.priorityHigh.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(widget.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.priorityHigh)),
        ),
      ),
    );
  }
}
