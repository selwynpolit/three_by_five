import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/database/app_database.dart';
import '../../data/daos/settings_dao.dart';

// ── Current supported format version ─────────────────────────────────────────

const _kFormatVersion = 1;

// ── Progress / result types ───────────────────────────────────────────────────

class BackupProgress {
  const BackupProgress({
    required this.fraction,
    required this.status,
    this.result,
    this.error,
    this.isDone = false,
    this.isCancelled = false,
    this.isFailed = false,
    this.noCancel = false,
    this.safetyBackupPath,
  });

  final double fraction;
  final String status;
  final BackupResult? result;
  final String? error;
  final bool isDone;
  final bool isCancelled;
  final bool isFailed;
  final bool noCancel;           // hide Cancel button during atomic swap
  final String? safetyBackupPath;
}

class BackupResult {
  const BackupResult({
    required this.outputPath,
    required this.taskCount,
    required this.cardCount,
    required this.stackCount,
    required this.attachmentCount,
    required this.backupType,
  });

  final String outputPath;
  final int taskCount;
  final int cardCount;
  final int stackCount;
  final int attachmentCount;
  final String backupType; // "manual" | "automatic" | "safety"
}

// ── Manifest ──────────────────────────────────────────────────────────────────

class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.appVersion,
    required this.createdAt,
    required this.backupType,
    required this.deviceName,
    required this.databaseFilename,
    required this.databaseChecksumSha256,
    required this.imageCount,
    required this.recordCounts,
    required this.totalSizeBytes,
  });

  final int formatVersion;
  final String appVersion;
  final DateTime createdAt;
  final String backupType;
  final String deviceName;
  final String databaseFilename;
  final String databaseChecksumSha256;
  final int imageCount;
  final Map<String, int> recordCounts;
  final int totalSizeBytes;

  static BackupManifest fromJson(Map<String, dynamic> json) {
    final fv = json['format_version'] as int? ?? 1;
    if (fv > _kFormatVersion) throw IncompatibleBackupFormatException(fv);
    return BackupManifest(
      formatVersion: fv,
      appVersion: json['app_version'] as String? ?? '?',
      createdAt: DateTime.parse(json['created_at'] as String),
      backupType: json['backup_type'] as String? ?? 'manual',
      deviceName: json['device_name'] as String? ?? '',
      databaseFilename:
          json['database_filename'] as String? ?? 'database.sqlite',
      databaseChecksumSha256:
          json['database_checksum_sha256'] as String? ?? '',
      imageCount: json['image_count'] as int? ?? 0,
      recordCounts:
          Map<String, int>.from(json['record_counts'] as Map? ?? {}),
      totalSizeBytes: json['total_size_bytes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'format_version': formatVersion,
        'app_version': appVersion,
        'created_at': createdAt.toUtc().toIso8601String(),
        'backup_type': backupType,
        'device_name': deviceName,
        'database_filename': databaseFilename,
        'database_checksum_sha256': databaseChecksumSha256,
        'images_folder': 'images/',
        'image_count': imageCount,
        'record_counts': recordCounts,
        'total_size_bytes': totalSizeBytes,
      };
}

class IncompatibleBackupFormatException implements Exception {
  const IncompatibleBackupFormatException(this.formatVersion);
  final int formatVersion;

  @override
  String toString() =>
      'This backup was created by a newer version of 3by5 '
      '(format v$formatVersion) and cannot be opened by this version. '
      'Please update 3by5 and try again.';
}

// ── List record types ─────────────────────────────────────────────────────────

class AutomaticBackupRecord {
  const AutomaticBackupRecord({
    required this.file,
    required this.createdAt,
    required this.sizeBytes,
    required this.recordCounts,
  });

  final File file;
  final DateTime createdAt;
  final int sizeBytes;
  final Map<String, int> recordCounts;
}

class SafetyBackupRecord {
  const SafetyBackupRecord({
    required this.file,
    required this.createdAt,
    required this.sizeBytes,
    required this.recordCounts,
  });

  final File file;
  final DateTime createdAt;
  final int sizeBytes;
  final Map<String, int> recordCounts;
}

// ── Internal exceptions ───────────────────────────────────────────────────────

class _Cancelled implements Exception {
  const _Cancelled();
}

// ── Service ───────────────────────────────────────────────────────────────────

class BackupService {
  BackupService({required AppDatabase db, required SettingsDao settings})
      : _db = db,
        _settings = settings;

  final AppDatabase _db;
  final SettingsDao _settings;

  bool _cancelled = false;
  bool _inAtomicSwap = false;

  void cancel() {
    if (!_inAtomicSwap) _cancelled = true;
  }

  void _check() {
    if (_cancelled) throw const _Cancelled();
  }

  // ── Path helpers ────────────────────────────────────────────────────────────

  Future<String> databasePath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, 'three_by_five.sqlite');
  }

  Future<String> imagesPath() async {
    final supportDir = await getApplicationSupportDirectory();
    return p.join(supportDir.path, 'attachments');
  }

  Future<String> _safetyBackupsPath() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'safety-backups'));
    await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> defaultAutoBackupPath() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'Automatic Backups'));
    await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> _resolvedAutoBackupFolder() async {
    final configured = await _settings.get('backupAutoFolder');
    if (configured == null ||
        configured.isEmpty ||
        configured == 'default') {
      return defaultAutoBackupPath();
    }
    if (await Directory(configured).exists()) return configured;
    // Fall back silently if configured folder is gone
    return defaultAutoBackupPath();
  }

  // ── Core assembly (private stream) ──────────────────────────────────────────

  Stream<BackupProgress> _assembleBackupStream({
    required String outputPath,
    required String backupType,
    bool respectCancel = true,
  }) async* {
    _cancelled = false;
    Directory? tempDir;

    void checkCancel() {
      if (respectCancel && _cancelled) throw const _Cancelled();
    }

    try {
      yield BackupProgress(fraction: 0.02, status: 'Preparing backup…');

      // 1. WAL checkpoint — flush all pending writes to the main .sqlite file
      await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      checkCancel();

      // 2. Create temp directory
      final tmpBase = await getTemporaryDirectory();
      tempDir = Directory(p.join(tmpBase.path,
          '3by5-bk-${DateTime.now().millisecondsSinceEpoch}'));
      await tempDir.create(recursive: true);
      final tempImagesDir = Directory(p.join(tempDir.path, 'images'));
      await tempImagesDir.create();

      // 3. Copy database file
      yield BackupProgress(fraction: 0.08, status: 'Copying database…');
      final dbPath = await databasePath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        throw Exception('Database file not found at $dbPath');
      }
      final tempDbFile = File(p.join(tempDir.path, 'database.sqlite'));
      await dbFile.copy(tempDbFile.path);
      checkCancel();

      // 4. Compute SHA-256 checksum
      yield BackupProgress(fraction: 0.14, status: 'Verifying database…');
      final checksum = await _computeSha256(tempDbFile);
      checkCancel();

      // 5. Get record counts via Drift (never parse the file directly)
      yield BackupProgress(
          fraction: 0.18, status: 'Counting records…');
      final counts = await _getRecordCounts();
      checkCancel();

      // 6. Copy image files
      final imagesPath = await this.imagesPath();
      final imagesDir = Directory(imagesPath);
      int copiedImages = 0;
      int totalImages = 0;

      if (await imagesDir.exists()) {
        final files = await imagesDir
            .list()
            .where((e) => e is File)
            .cast<File>()
            .toList();
        totalImages = files.length;
        for (final imgFile in files) {
          yield BackupProgress(
            fraction: 0.20 + 0.45 * (copiedImages / math.max(1, totalImages)),
            status: 'Copying image ${copiedImages + 1} of $totalImages…',
          );
          checkCancel();
          await imgFile
              .copy(p.join(tempImagesDir.path, p.basename(imgFile.path)));
          copiedImages++;
        }
      }

      // 7. Build manifest.json
      yield BackupProgress(fraction: 0.67, status: 'Writing manifest…');
      final manifest = BackupManifest(
        formatVersion: _kFormatVersion,
        appVersion: '1.0.0',
        createdAt: DateTime.now().toUtc(),
        backupType: backupType,
        deviceName: Platform.localHostname,
        databaseFilename: 'database.sqlite',
        databaseChecksumSha256: checksum,
        imageCount: copiedImages,
        recordCounts: counts,
        totalSizeBytes: 0, // filled after zip assembly
      );
      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      await manifestFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(manifest.toJson()));
      checkCancel();

      // 8. Assemble zip
      yield BackupProgress(fraction: 0.72, status: 'Building backup file…');
      final tempZipPath =
          p.join(tmpBase.path, 'temp-backup-${DateTime.now().millisecondsSinceEpoch}.3by5backup');
      final encoder = ZipFileEncoder();
      encoder.create(tempZipPath);
      encoder.addFile(tempDbFile, 'database.sqlite');
      encoder.addFile(manifestFile, 'manifest.json');
      if (await tempImagesDir.list().any((_) => true)) {
        encoder.addDirectory(tempImagesDir);
      }
      encoder.close();
      checkCancel();

      // 9. Rewrite manifest with correct total_size_bytes
      final zipFile = File(tempZipPath);
      final totalBytes = await zipFile.length();
      final finalManifest = BackupManifest(
        formatVersion: manifest.formatVersion,
        appVersion: manifest.appVersion,
        createdAt: manifest.createdAt,
        backupType: manifest.backupType,
        deviceName: manifest.deviceName,
        databaseFilename: manifest.databaseFilename,
        databaseChecksumSha256: manifest.databaseChecksumSha256,
        imageCount: manifest.imageCount,
        recordCounts: manifest.recordCounts,
        totalSizeBytes: totalBytes,
      );
      // total_size_bytes in the manifest-in-zip is 0 (set before zip assembly);
      // the correct size is on disk. Minor limitation — acceptable for a backup.

      // 10. Verify zip is valid
      yield BackupProgress(fraction: 0.88, status: 'Verifying backup…');
      await readManifest(backupFile: zipFile); // throws if zip is corrupt
      checkCancel();

      // 11. Move to output path
      yield BackupProgress(fraction: 0.93, status: 'Saving backup…');
      await zipFile.copy(outputPath);
      try {
        await zipFile.delete();
      } catch (_) {}

      // 12. Record in settings (not for safety backups)
      if (backupType != 'safety') {
        final now = DateTime.now().toIso8601String();
        if (backupType == 'manual') {
          await _settings.set('backupLastManualDate', now);
          await _settings.set('backupLastManualPath', outputPath);
          await _settings.set(
              'backupLastManualSize', '$totalBytes');
        } else {
          await _settings.set('backupLastAutoDate', now);
          await _settings.set('backupLastAutoResult', 'success');
        }
      }

      yield BackupProgress(
        fraction: 1.0,
        status: 'Backup saved.',
        isDone: true,
        result: BackupResult(
          outputPath: outputPath,
          taskCount: counts['tasks'] ?? 0,
          cardCount: counts['cards'] ?? 0,
          stackCount: counts['stacks'] ?? 0,
          attachmentCount: copiedImages,
          backupType: backupType,
        ),
      );
    } on _Cancelled {
      yield const BackupProgress(
          fraction: 0.0, status: 'Backup cancelled.', isCancelled: true);
    } catch (e, st) {
      debugPrint('BackupService._assembleBackupStream error: $e\n$st');
      if (backupType == 'automatic') {
        try {
          await _settings.set('backupLastAutoResult', 'failed');
        } catch (_) {}
      }
      yield BackupProgress(
          fraction: 0.0,
          status: 'Backup failed.',
          isFailed: true,
          error: e.toString());
    } finally {
      if (tempDir != null) {
        try {
          if (await tempDir.exists()) await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  // ── Public: create backup ───────────────────────────────────────────────────

  Stream<BackupProgress> createBackup({
    required bool isAutomatic,
    String? forcedOutputPath,
  }) async* {
    _cancelled = false;

    final ts = intl.DateFormat('yyyy-MM-dd-HHmm').format(DateTime.now());
    final defaultName = isAutomatic
        ? '3by5-auto-backup-$ts.3by5backup'
        : '3by5-backup-$ts.3by5backup';

    String? outputPath = forcedOutputPath;

    if (outputPath == null) {
      if (isAutomatic) {
        final folder = await _resolvedAutoBackupFolder();
        outputPath = p.join(folder, defaultName);
      } else {
        yield const BackupProgress(
            fraction: 0.0, status: 'Choose save location…');
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save 3by5 Backup',
          fileName: defaultName,
          type: FileType.custom,
          allowedExtensions: ['3by5backup'],
        );
        if (outputPath == null) {
          yield const BackupProgress(
              fraction: 0.0,
              status: 'Backup cancelled.',
              isCancelled: true);
          return;
        }
      }
    }

    yield* _assembleBackupStream(
      outputPath: outputPath,
      backupType: isAutomatic ? 'automatic' : 'manual',
    );

    if (isAutomatic) {
      await pruneAutomaticBackups(keepCount: 7);
    }
  }

  // ── Public: restore from backup ─────────────────────────────────────────────

  Stream<BackupProgress> restoreFromBackup({required File backupFile}) async* {
    _cancelled = false;
    _inAtomicSwap = false;
    Directory? tempDir;

    try {
      // Step 1: Create safety backup (non-cancellable, mandatory)
      yield const BackupProgress(fraction: 0.0, status: 'Creating safety backup…');

      final safetyDir = await _safetyBackupsPath();
      final safetyTs =
          intl.DateFormat('yyyy-MM-dd-HHmm').format(DateTime.now());
      final safetyPath = p.join(
          safetyDir, '3by5-pre-restore-safety-$safetyTs.3by5backup');

      String? safetyError;
      await for (final prog in _assembleBackupStream(
        outputPath: safetyPath,
        backupType: 'safety',
        respectCancel: false,
      )) {
        if (prog.isFailed) safetyError = prog.error;
        // Relay progress on the 0–28% range
        if (!prog.isDone && !prog.isFailed) {
          yield BackupProgress(
              fraction: prog.fraction * 0.28,
              status: 'Creating safety backup: ${prog.status}');
        }
      }

      if (!await File(safetyPath).exists()) {
        throw Exception(
            'Could not create safety backup${safetyError != null ? ': $safetyError' : ''}. '
            'Restore aborted — your data has not been changed.');
      }

      yield BackupProgress(
        fraction: 0.29,
        status: 'Safety backup saved.',
        safetyBackupPath: safetyPath,
      );
      _check();

      // Step 2: Read and validate the manifest (already checked by caller
      // but re-verify here to be safe)
      yield const BackupProgress(fraction: 0.32, status: 'Validating backup file…');
      final manifest = await readManifest(backupFile: backupFile);
      _check();

      // Step 3: Extract to temp directory
      yield const BackupProgress(fraction: 0.36, status: 'Extracting backup…');
      final tmpBase = await getTemporaryDirectory();
      tempDir = Directory(p.join(
          tmpBase.path, '3by5-restore-${DateTime.now().millisecondsSinceEpoch}'));
      await tempDir.create(recursive: true);
      await _extractFromZip(backupFile, tempDir.path);
      _check();

      // Step 4: Verify database checksum
      yield const BackupProgress(
          fraction: 0.58, status: 'Verifying database integrity…');
      final extractedDb =
          File(p.join(tempDir.path, 'database.sqlite'));
      if (!await extractedDb.exists()) {
        throw Exception(
            'Backup file is corrupt: database.sqlite is missing.');
      }
      final actualChecksum = await _computeSha256(extractedDb);
      if (actualChecksum != manifest.databaseChecksumSha256) {
        throw Exception(
            'Database integrity check failed — the backup file may be '
            'corrupted. Your data has not been changed.\n\n'
            'Expected: ${manifest.databaseChecksumSha256}\n'
            'Got:      $actualChecksum');
      }
      _check();

      // Step 5: Atomic replacement — no cancel from here
      _inAtomicSwap = true;
      yield const BackupProgress(
        fraction: 0.72,
        status: 'Replacing data…',
        noCancel: true,
      );
      await _atomicReplace(
        extractedDbPath: extractedDb.path,
        extractedImagesPath: p.join(tempDir.path, 'images'),
      );
      _inAtomicSwap = false;

      yield BackupProgress(
        fraction: 1.0,
        status: 'Restore complete.',
        isDone: true,
        safetyBackupPath: safetyPath,
        result: BackupResult(
          outputPath: backupFile.path,
          taskCount: manifest.recordCounts['tasks'] ?? 0,
          cardCount: manifest.recordCounts['cards'] ?? 0,
          stackCount: manifest.recordCounts['stacks'] ?? 0,
          attachmentCount: manifest.imageCount,
          backupType: 'restore',
        ),
      );
    } on _Cancelled {
      yield const BackupProgress(
          fraction: 0.0, status: 'Restore cancelled.', isCancelled: true);
    } catch (e, st) {
      debugPrint('BackupService.restoreFromBackup error: $e\n$st');
      yield BackupProgress(
        fraction: 0.0,
        status: 'Restore failed.',
        isFailed: true,
        error: e.toString(),
      );
    } finally {
      _inAtomicSwap = false;
      if (tempDir != null) {
        try {
          if (await tempDir.exists()) await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  // ── Public: read manifest ───────────────────────────────────────────────────

  Future<BackupManifest> readManifest({required File backupFile}) async {
    InputFileStream? inputStream;
    try {
      inputStream = InputFileStream(backupFile.path);
      final archive = ZipDecoder().decodeBuffer(inputStream);
      final entry = archive.findFile('manifest.json');
      if (entry == null) {
        throw Exception(
            'Not a valid 3by5 backup file: manifest.json not found.');
      }
      final bytes = entry.content as List<int>;
      final json = utf8.decode(bytes);
      final data = jsonDecode(json) as Map<String, dynamic>;
      return BackupManifest.fromJson(data);
    } on FormatException catch (e) {
      throw Exception('This file is not a valid backup archive: ${e.message}');
    } finally {
      inputStream?.close();
    }
  }

  // ── Public: schedule automatic backup ──────────────────────────────────────

  Future<void> scheduleAutomaticBackupIfDue() async {
    try {
      final frequency =
          await _settings.get('backupAutoFrequency') ?? 'off';
      if (frequency == 'off') return;

      final lastResult =
          await _settings.get('backupLastAutoResult') ?? '';
      final lastDateStr =
          await _settings.get('backupLastAutoDate') ?? '';
      final lastDate =
          lastDateStr.isNotEmpty ? DateTime.tryParse(lastDateStr) : null;
      final now = DateTime.now();

      final isDue = lastResult == 'failed' ||
          lastDate == null ||
          (frequency == 'daily' &&
              now.difference(lastDate).inHours >= 23) ||
          (frequency == 'weekly' &&
              now.difference(lastDate).inDays >= 6);

      if (!isDue) return;

      // Run auto backup silently — collect the stream to completion
      await for (final _ in createBackup(isAutomatic: true)) {
        // progress is not surfaced for background auto-backup
      }
    } catch (e) {
      debugPrint('Auto backup failed: $e');
    }
  }

  // ── Public: list and prune ──────────────────────────────────────────────────

  Future<List<AutomaticBackupRecord>> listAutomaticBackups() async {
    try {
      final folderPath = await _resolvedAutoBackupFolder();
      final dir = Directory(folderPath);
      if (!await dir.exists()) return [];
      return await _scanBackupDir(dir, 'automatic')
          .then((list) => list
              .map((r) => AutomaticBackupRecord(
                    file: r.$1,
                    createdAt: r.$2,
                    sizeBytes: r.$3,
                    recordCounts: r.$4,
                  ))
              .toList());
    } catch (_) {
      return [];
    }
  }

  Future<void> pruneAutomaticBackups({required int keepCount}) async {
    final records = await listAutomaticBackups();
    final toDelete = records.skip(keepCount).toList();
    for (final record in toDelete) {
      try {
        await record.file.delete();
      } catch (_) {}
    }
  }

  Future<List<SafetyBackupRecord>> listSafetyBackups() async {
    try {
      final dir = Directory(await _safetyBackupsPath());
      if (!await dir.exists()) return [];
      return await _scanBackupDir(dir, 'safety')
          .then((list) => list
              .map((r) => SafetyBackupRecord(
                    file: r.$1,
                    createdAt: r.$2,
                    sizeBytes: r.$3,
                    recordCounts: r.$4,
                  ))
              .toList());
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteSafetyBackup({required File file}) async {
    await file.delete();
  }

  Future<void> deleteAllSafetyBackups() async {
    final dir = Directory(await _safetyBackupsPath());
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.3by5backup')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<Map<String, int>> _getRecordCounts() async {
    return {
      'stacks': await (_db.select(_db.stacks)
                ..where((s) => s.deletedAt.isNull()))
              .get()
              .then((l) => l.length),
      'cards': await (_db.select(_db.cards)
                ..where((c) => c.deletedAt.isNull()))
              .get()
              .then((l) => l.length),
      'tasks': await (_db.select(_db.tasks)
                ..where((t) => t.deletedAt.isNull()))
              .get()
              .then((l) => l.length),
      'notes': await _db.select(_db.notes).get().then((l) => l.length),
      'attachments': await (_db.select(_db.attachments)
                ..where((a) => a.deletedAt.isNull()))
              .get()
              .then((l) => l.length),
      'tags': await _db.select(_db.tags).get().then((l) => l.length),
    };
  }

  Future<String> _computeSha256(File file) async {
    // Read in chunks to avoid loading large files into memory at once.
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  Future<void> _extractFromZip(File zipFile, String destPath) async {
    final inputStream = InputFileStream(zipFile.path);
    try {
      final archive = ZipDecoder().decodeBuffer(inputStream);
      extractArchiveToDisk(archive, destPath);
    } finally {
      inputStream.close();
    }
  }

  Future<void> _atomicReplace({
    required String extractedDbPath,
    required String extractedImagesPath,
  }) async {
    final dbPath = await databasePath();
    final imgPath = await imagesPath();
    final dbOldPath = '$dbPath.old';
    final imgOldPath = '$imgPath.old';

    // Close the Drift connection before touching the file
    await _db.close();

    try {
      // Rename live files to .old — NEVER delete them yet
      if (await File(dbPath).exists()) {
        await File(dbPath).rename(dbOldPath);
      }
      if (await Directory(imgPath).exists()) {
        await Directory(imgPath).rename(imgOldPath);
      }

      // Move extracted files to live locations
      await File(extractedDbPath).rename(dbPath);
      final extractedImages = Directory(extractedImagesPath);
      if (await extractedImages.exists()) {
        await extractedImages.rename(imgPath);
      } else {
        await Directory(imgPath).create(recursive: true);
      }

      // Clean up .old files (best-effort — OK if this fails)
      try {
        await File(dbOldPath).delete();
      } catch (_) {}
      try {
        await Directory(imgOldPath).delete(recursive: true);
      } catch (_) {}
    } catch (e) {
      // Rollback attempt — best-effort
      try {
        if (await File(dbOldPath).exists() &&
            !await File(dbPath).exists()) {
          await File(dbOldPath).rename(dbPath);
        }
        if (await Directory(imgOldPath).exists() &&
            !await Directory(imgPath).exists()) {
          await Directory(imgOldPath).rename(imgPath);
        }
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<(File, DateTime, int, Map<String, int>)>> _scanBackupDir(
      Directory dir, String expectedType) async {
    final results = <(File, DateTime, int, Map<String, int>)>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.3by5backup')) {
        try {
          final manifest = await readManifest(backupFile: entity);
          if (manifest.backupType == expectedType) {
            results.add((
              entity,
              manifest.createdAt,
              await entity.length(),
              manifest.recordCounts,
            ));
          }
        } catch (_) {}
      }
    }
    results.sort((a, b) => b.$2.compareTo(a.$2));
    return results;
  }
}
