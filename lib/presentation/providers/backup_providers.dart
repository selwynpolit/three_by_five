import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/backup_service.dart';
import '../../data/daos/settings_dao.dart';
import 'database_provider.dart';

// ── Settings keys ─────────────────────────────────────────────────────────────

const _kAutoFrequency = 'backupAutoFrequency';
const _kAutoFolder = 'backupAutoFolder';
const _kLastManualDate = 'backupLastManualDate';
const _kLastManualSize = 'backupLastManualSize';

// ── Visibility flags ──────────────────────────────────────────────────────────

final backupPanelVisibleProvider  = StateProvider<bool>((ref) => false);
final restorePanelVisibleProvider = StateProvider<bool>((ref) => false);

// ── Service ───────────────────────────────────────────────────────────────────

final backupServiceProvider = Provider<BackupService>((ref) => BackupService(
      db: ref.watch(appDatabaseProvider),
      settings: ref.watch(settingsDaoProvider),
    ));

// ── Settings watchers ─────────────────────────────────────────────────────────

final autoBackupFrequencyProvider = StreamProvider<String>((ref) {
  return ref
      .watch(settingsDaoProvider)
      .watch(_kAutoFrequency)
      .map((v) => v ?? 'off');
});

final autoBackupFolderProvider = StreamProvider<String?>((ref) {
  return ref.watch(settingsDaoProvider).watch(_kAutoFolder);
});

final lastManualBackupDateProvider = StreamProvider<DateTime?>((ref) {
  return ref
      .watch(settingsDaoProvider)
      .watch(_kLastManualDate)
      .map((v) => v != null ? DateTime.tryParse(v) : null);
});

final lastManualBackupSizeProvider = StreamProvider<int?>((ref) {
  return ref
      .watch(settingsDaoProvider)
      .watch(_kLastManualSize)
      .map((v) => v != null ? int.tryParse(v) : null);
});

// ── Auto-backup settings controller ──────────────────────────────────────────
// Provider-layer write path for auto-backup settings. UI widgets mutate these
// settings through this controller and never touch SettingsDao directly. The
// StreamProviders above pick up the change reactively (Drift watch()).

class AutoBackupSettingsController {
  AutoBackupSettingsController(this._settings);
  final SettingsDao _settings;

  Future<void> setFrequency(String value) =>
      _settings.set(_kAutoFrequency, value);

  Future<void> setFolder(String path) => _settings.set(_kAutoFolder, path);
}

final autoBackupSettingsControllerProvider =
    Provider<AutoBackupSettingsController>(
  (ref) => AutoBackupSettingsController(ref.watch(settingsDaoProvider)),
);

final safetyBackupsProvider = FutureProvider<List<SafetyBackupRecord>>((ref) {
  return ref.read(backupServiceProvider).listSafetyBackups();
});

// ── Backup state ──────────────────────────────────────────────────────────────

enum BackupPhase { idle, running, done, failed, cancelled }

class BackupState {
  const BackupState({
    this.phase = BackupPhase.idle,
    this.fraction = 0.0,
    this.status = '',
    this.result,
    this.error,
  });

  final BackupPhase phase;
  final double fraction;
  final String status;
  final BackupResult? result;
  final String? error;

  bool get isActive => phase == BackupPhase.running;
}

class BackupNotifier extends StateNotifier<BackupState> {
  BackupNotifier(this._service) : super(const BackupState());
  final BackupService _service;
  StreamSubscription<BackupProgress>? _sub;

  void startBackup() {
    _sub?.cancel();
    state = const BackupState(phase: BackupPhase.running, status: 'Starting…');
    _sub = _service.createBackup(isAutomatic: false).listen(
      (p) {
        if (p.isDone) {
          state = BackupState(
              phase: BackupPhase.done,
              fraction: 1.0,
              status: p.status,
              result: p.result);
        } else if (p.isCancelled) {
          state = const BackupState(phase: BackupPhase.cancelled);
        } else if (p.isFailed) {
          state = BackupState(
              phase: BackupPhase.failed, status: p.status, error: p.error);
        } else {
          state = BackupState(
              phase: BackupPhase.running,
              fraction: p.fraction,
              status: p.status);
        }
      },
      onError: (e) =>
          state = BackupState(phase: BackupPhase.failed, error: e.toString()),
    );
  }

  void cancel() {
    _service.cancel();
    _sub?.cancel();
    state = const BackupState(phase: BackupPhase.cancelled);
  }

  void reset() {
    _sub?.cancel();
    state = const BackupState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final backupNotifierProvider =
    StateNotifierProvider<BackupNotifier, BackupState>(
        (ref) => BackupNotifier(ref.watch(backupServiceProvider)));

// ── Restore state ─────────────────────────────────────────────────────────────

enum RestorePhase {
  idle,
  reading,   // reading manifest from selected file
  preview,   // showing manifest, awaiting user confirmation
  running,   // restore in progress
  done,      // complete — showing countdown to restart
  failed,
  cancelled,
}

class RestoreState {
  const RestoreState({
    this.phase = RestorePhase.idle,
    this.fraction = 0.0,
    this.status = '',
    this.manifest,
    this.selectedFile,
    this.result,
    this.error,
    this.safetyBackupPath,
    this.noCancel = false,
  });

  final RestorePhase phase;
  final double fraction;
  final String status;
  final BackupManifest? manifest;
  final File? selectedFile;
  final BackupResult? result;
  final String? error;
  final String? safetyBackupPath;
  final bool noCancel; // hide Cancel during atomic swap
}

class RestoreNotifier extends StateNotifier<RestoreState> {
  RestoreNotifier(this._service) : super(const RestoreState());
  final BackupService _service;
  StreamSubscription<BackupProgress>? _sub;

  Future<void> pickAndReadManifest() async {
    state = const RestoreState(phase: RestorePhase.reading, status: 'Opening…');

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['3by5backup'],
      dialogTitle: 'Select a 3by5 Backup File',
    );

    if (result == null || result.files.isEmpty) {
      state = const RestoreState();
      return;
    }

    final file = File(result.files.first.path!);
    try {
      final manifest = await _service.readManifest(backupFile: file);
      state = RestoreState(
          phase: RestorePhase.preview, selectedFile: file, manifest: manifest);
    } on IncompatibleBackupFormatException catch (e) {
      state = RestoreState(
          phase: RestorePhase.failed, error: e.toString(), selectedFile: file);
    } catch (e) {
      state = RestoreState(
          phase: RestorePhase.failed,
          error: 'Could not read backup file: $e',
          selectedFile: file);
    }
  }

  void startRestore() {
    final file = state.selectedFile;
    if (file == null) return;
    final manifest = state.manifest;

    _sub?.cancel();
    state = RestoreState(
      phase: RestorePhase.running,
      fraction: 0.0,
      status: 'Starting restore…',
      selectedFile: file,
      manifest: manifest,
    );

    _sub = _service.restoreFromBackup(backupFile: file).listen(
      (p) {
        if (p.isDone) {
          state = RestoreState(
            phase: RestorePhase.done,
            fraction: 1.0,
            status: p.status,
            selectedFile: file,
            manifest: manifest,
            result: p.result,
            safetyBackupPath: p.safetyBackupPath,
          );
        } else if (p.isCancelled) {
          state = const RestoreState(phase: RestorePhase.cancelled);
        } else if (p.isFailed) {
          state = RestoreState(
            phase: RestorePhase.failed,
            status: p.status,
            error: p.error,
            selectedFile: file,
            manifest: manifest,
          );
        } else {
          state = RestoreState(
            phase: RestorePhase.running,
            fraction: p.fraction,
            status: p.status,
            noCancel: p.noCancel,
            selectedFile: file,
            manifest: manifest,
            safetyBackupPath: p.safetyBackupPath,
          );
        }
      },
      onError: (e) =>
          state = RestoreState(phase: RestorePhase.failed, error: e.toString()),
    );
  }

  void cancel() {
    _service.cancel();
    _sub?.cancel();
    state = const RestoreState(phase: RestorePhase.cancelled);
  }

  void reset() {
    _sub?.cancel();
    state = const RestoreState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final restoreNotifierProvider =
    StateNotifierProvider<RestoreNotifier, RestoreState>(
        (ref) => RestoreNotifier(ref.watch(backupServiceProvider)));
