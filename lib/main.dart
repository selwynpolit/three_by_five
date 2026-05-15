import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

void main() {
  // runZonedGuarded must wrap ensureInitialized to avoid zone mismatch warning.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(900, 600),
        center: true,
        title: '3by5',
        titleBarStyle: TitleBarStyle.normal,
        backgroundColor: Color(0xFF3A5544),
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      runApp(const ProviderScope(child: ThreeByFiveApp()));
    },
    (error, stack) {
      // Suppress known flutter_quill paste assertion (Line.retain bounds check)
      if (error is AssertionError && stack.toString().contains('line.dart')) {
        return;
      }
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}
