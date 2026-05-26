import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'presentation/providers/backup_providers.dart';
import 'presentation/providers/export_providers.dart';
import 'presentation/widgets/about_dialog.dart';
import 'presentation/providers/help_providers.dart';
import 'presentation/shell/app_shell.dart';

class ThreeByFiveApp extends ConsumerWidget {
  const ThreeByFiveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openHelp() =>
        ref.read(helpPanelVisibleProvider.notifier).state = true;

    void openExport() {
      ref.read(exportNotifierProvider.notifier).reset();
      ref.read(exportPanelVisibleProvider.notifier).state = true;
    }

    void openBackup() {
      ref.read(backupNotifierProvider.notifier).reset();
      ref.read(backupPanelVisibleProvider.notifier).state = true;
    }

    void openRestore() {
      ref.read(restoreNotifierProvider.notifier).reset();
      ref.read(restorePanelVisibleProvider.notifier).state = true;
    }

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: '3by5',
          menus: [
            PlatformMenuItem(
              label: 'About 3by5',
              onSelected: () =>
                  ref.read(showAboutDialogProvider.notifier).state = true,
            ),
            PlatformMenuItem(
              label: 'Hide 3by5',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyH, meta: true),
              onSelected: windowManager.hide,
            ),
            PlatformMenuItem(
              label: 'Quit 3by5',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyQ, meta: true),
              onSelected: () => exit(0),
            ),
          ],
        ),
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'Create Backup',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyB,
                meta: true,
                shift: true,
              ),
              onSelected: openBackup,
            ),
            PlatformMenuItem(
              label: 'Restore from Backup',
              onSelected: openRestore,
            ),
            PlatformMenuItem(
              label: 'Export Data',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyE,
                meta: true,
                shift: true,
              ),
              onSelected: openExport,
            ),
          ],
        ),
        PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItem(
              label: 'Undo',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyZ, meta: true),
              onSelected: () {},
            ),
            PlatformMenuItem(
              label: 'Redo',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyZ, meta: true, shift: true),
              onSelected: () {},
            ),
            PlatformMenuItem(
              label: 'Cut',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyX, meta: true),
              onSelected: () {},
            ),
            PlatformMenuItem(
              label: 'Copy',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyC, meta: true),
              onSelected: () {},
            ),
            PlatformMenuItem(
              label: 'Paste',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyV, meta: true),
              onSelected: () {},
            ),
            PlatformMenuItem(
              label: 'Select All',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyA, meta: true),
              onSelected: () {},
            ),
          ],
        ),
        PlatformMenu(
          label: 'Help',
          menus: [
            PlatformMenuItem(
              label: '3by5 Help',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.slash,
                meta: true,
                shift: true,
              ),
              onSelected: openHelp,
            ),
          ],
        ),
      ],
      child: MaterialApp(
        title: '3by5',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        localizationsDelegates: const [
          FlutterQuillLocalizations.delegate,
        ],
        home: const AppShell(),
      ),
    );
  }
}
