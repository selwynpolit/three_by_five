import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'presentation/shell/app_shell.dart';

class ThreeByFiveApp extends ConsumerWidget {
  const ThreeByFiveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '3by5',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
      ],
      home: const AppShell(),
    );
  }
}
