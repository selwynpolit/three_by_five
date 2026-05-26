import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/export_service.dart';
import 'database_provider.dart';

// ── Visibility flags ──────────────────────────────────────────────────────────

final settingsPanelVisibleProvider = StateProvider<bool>((ref) => false);
final exportPanelVisibleProvider   = StateProvider<bool>((ref) => false);
final showAboutDialogProvider      = StateProvider<bool>((ref) => false);

// ── ExportService (singleton, re-created on demand) ───────────────────────────

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(ref.watch(appDatabaseProvider)),
);

// ── Export state ──────────────────────────────────────────────────────────────

enum ExportPhase { idle, running, done, empty, failed, cancelled }

class ExportState {
  const ExportState({
    this.phase = ExportPhase.idle,
    this.fraction = 0.0,
    this.status = '',
    this.result,
    this.error,
  });

  final ExportPhase phase;
  final double fraction;
  final String status;
  final ExportResult? result;
  final String? error;

  bool get isActive => phase == ExportPhase.running;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ExportNotifier extends StateNotifier<ExportState> {
  ExportNotifier(this._service) : super(const ExportState());
  final ExportService _service;
  StreamSubscription<ExportProgress>? _sub;

  void startExport() {
    _sub?.cancel();
    state = const ExportState(
        phase: ExportPhase.running, status: 'Starting…');
    _sub = _service.start().listen(
      (p) {
        if (p.isDone) {
          state = ExportState(
            phase: p.isEmpty ? ExportPhase.empty : ExportPhase.done,
            fraction: 1.0,
            status: p.status,
            result: p.result,
          );
        } else if (p.isCancelled) {
          state = const ExportState(phase: ExportPhase.cancelled);
        } else if (p.error != null) {
          state = ExportState(
              phase: ExportPhase.failed,
              status: p.status,
              error: p.error);
        } else {
          state = ExportState(
              phase: ExportPhase.running,
              fraction: p.fraction,
              status: p.status);
        }
      },
      onError: (e) => state = ExportState(
          phase: ExportPhase.failed, error: e.toString()),
    );
  }

  void cancel() {
    _service.cancel();
    _sub?.cancel();
    state = const ExportState(phase: ExportPhase.cancelled);
  }

  void reset() {
    _sub?.cancel();
    state = const ExportState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final exportNotifierProvider =
    StateNotifierProvider<ExportNotifier, ExportState>(
  (ref) => ExportNotifier(ref.watch(exportServiceProvider)),
);
