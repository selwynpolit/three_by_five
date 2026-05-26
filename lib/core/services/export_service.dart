import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show OrderingTerm, NullsOrder;

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/database/app_database.dart';

// ── Progress / result value types ─────────────────────────────────────────────

class ExportProgress {
  const ExportProgress({
    required this.fraction,
    required this.status,
    this.result,
    this.error,
    this.isDone = false,
    this.isCancelled = false,
    this.isEmpty = false,
  });

  final double fraction; // 0.0–1.0
  final String status;
  final ExportResult? result; // non-null when isDone && !isEmpty
  final String? error;        // non-null when failed
  final bool isDone;
  final bool isCancelled;
  final bool isEmpty;
}

class ExportResult {
  const ExportResult({
    required this.taskCount,
    required this.attachmentCount,
    required this.missingFileCount,
    required this.outputPath,
  });

  final int taskCount;
  final int attachmentCount;
  final int missingFileCount;
  final String outputPath;
}

class _Cancelled implements Exception {
  const _Cancelled();
}

// ── In-memory data bundle ─────────────────────────────────────────────────────

class _D {
  const _D({
    required this.stacks,
    required this.cards,
    required this.tasks,
    required this.notesByTask,
    required this.attsByTask,
    required this.tagIdsByTask,
    required this.tagsById,
    required this.colsById,
  });

  final Map<String, AppStack> stacks;
  final Map<String, AppCard> cards;
  final List<AppTask> tasks;
  final Map<String, List<AppNote>> notesByTask;
  final Map<String, List<AppAttachment>> attsByTask;
  final Map<String, List<String>> tagIdsByTask;
  final Map<String, AppTag> tagsById;
  final Map<String, AppBoardColumn> colsById;
}

// ── Date / text formatters (module-level, reused across calls) ────────────────

final _dateFmt     = intl.DateFormat('EEE d MMM yyyy');
final _noteFmt     = intl.DateFormat('EEE d MMM yyyy HH:mm');
final _isoDateFmt  = intl.DateFormat('yyyyMMdd');

// ── Service ───────────────────────────────────────────────────────────────────

class ExportService {
  ExportService(this._db);
  final AppDatabase _db;

  bool _cancelled = false;
  void cancel() => _cancelled = true;
  void _check() { if (_cancelled) throw const _Cancelled(); }

  // ── Public entry ────────────────────────────────────────────────────────────

  Stream<ExportProgress> start() async* {
    _cancelled = false;
    Directory? tempDir;

    try {
      // 1. Load all data (0 → 8%)
      yield const ExportProgress(fraction: 0.00, status: 'Loading tasks…');
      final d = await _loadAll();
      _check();

      if (d.tasks.isEmpty) {
        yield const ExportProgress(
          fraction: 1.0,
          status: 'Nothing to export yet — add some tasks first.',
          isDone: true,
          isEmpty: true,
        );
        return;
      }

      // 2. Create temp directory
      yield const ExportProgress(fraction: 0.08, status: 'Preparing export…');
      final tmpBase = await getTemporaryDirectory();
      tempDir = Directory(
          p.join(tmpBase.path, '3by5-${DateTime.now().millisecondsSinceEpoch}'));
      await tempDir.create(recursive: true);
      final attDir = Directory(p.join(tempDir.path, 'attachments'));
      await attDir.create();
      _check();

      final dateTag = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 3. Pre-compute archive paths for all attachments so CSV rows reference
      //    the correct filenames before we physically copy anything.
      final archivePaths = _computeArchivePaths(d);

      // 4. Build main CSV (8 → 25%)
      yield const ExportProgress(fraction: 0.08, status: 'Building task list…');
      final mainCsv = _buildMainCsv(d, archivePaths, dateTag);
      await File(p.join(tempDir.path, '3by5-export-$dateTag.csv'))
          .writeAsBytes(mainCsv);
      _check();

      // 5. Build summary CSV (25 → 32%)
      yield const ExportProgress(fraction: 0.25, status: 'Building summary…');
      final summaryCsv = _buildSummaryCsv(d, dateTag);
      await File(p.join(tempDir.path, '3by5-export-$dateTag-summary.csv'))
          .writeAsBytes(summaryCsv);
      _check();

      // 6. Copy image files (32 → 68%)
      final imageAtts = d.attsByTask.values
          .expand((l) => l.where((a) => a.type == 'image'))
          .toList();
      final totalImages = imageAtts.length;
      var copiedImages = 0;
      var missingFiles = 0;
      final manifestEntries = <Map<String, dynamic>>[];

      for (final att in imageAtts) {
        yield ExportProgress(
          fraction: 0.32 + 0.36 * (copiedImages / math.max(1, totalImages)),
          status: 'Copying image ${copiedImages + 1} of $totalImages…',
        );
        _check();

        final src = att.filePath;
        final archivePath = archivePaths[att.id];
        if (src == null || archivePath == null) { copiedImages++; continue; }

        final srcFile = File(src);
        final destFile = File(p.join(tempDir.path, archivePath));

        String fileStatus;
        int? sizeBytes;
        if (await srcFile.exists()) {
          await srcFile.copy(destFile.path);
          sizeBytes = await destFile.length();
          fileStatus = 'ok';
        } else {
          missingFiles++;
          fileStatus = 'missing';
        }

        final task = d.tasks.where((t) => t.id == att.taskId).firstOrNull;
        manifestEntries.add({
          'filename': p.basename(archivePath),
          'type': 'image',
          'task_title': task?.title ?? '',
          'task_uuid': att.taskId,
          'original_filename': p.basename(src),
          if (sizeBytes != null) 'size_bytes': sizeBytes,
          'status': fileStatus,
        });
        copiedImages++;
      }

      // 7. Write email clip text files (68 → 76%)
      final emailAtts = d.attsByTask.values
          .expand((l) => l.where((a) => a.type == 'emailClip'))
          .toList();
      final totalEmails = emailAtts.length;
      var writtenEmails = 0;

      for (final att in emailAtts) {
        yield ExportProgress(
          fraction: 0.68 + 0.08 * (writtenEmails / math.max(1, totalEmails)),
          status: 'Writing email clip ${writtenEmails + 1} of $totalEmails…',
        );
        _check();

        final archivePath = archivePaths[att.id];
        if (archivePath == null) { writtenEmails++; continue; }

        final destFile = File(p.join(tempDir.path, archivePath));
        await destFile.writeAsString(_reconstructEmailClip(att), encoding: utf8);

        final task = d.tasks.where((t) => t.id == att.taskId).firstOrNull;
        manifestEntries.add({
          'filename': p.basename(archivePath),
          'type': 'emailClip',
          'task_title': task?.title ?? '',
          'task_uuid': att.taskId,
          'original_filename': p.basename(archivePath),
          'size_bytes': await destFile.length(),
          'status': 'ok',
        });
        writtenEmails++;
      }

      // 8. Write manifest.json (76 → 80%)
      yield const ExportProgress(fraction: 0.76, status: 'Writing manifest…');
      final manifest = {
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'app_version': '1.0.0',
        'total_files': manifestEntries.length,
        'files': manifestEntries,
      };
      await File(p.join(attDir.path, 'manifest.json'))
          .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
      _check();

      // 9. Write README.txt (80 → 84%)
      yield const ExportProgress(fraction: 0.80, status: 'Writing README…');
      await File(p.join(tempDir.path, 'README.txt'))
          .writeAsString(_buildReadme(d, dateTag));
      _check();

      // 10. Assemble ZIP (84 → 91%)
      yield const ExportProgress(fraction: 0.84, status: 'Building zip…');
      final zipPath = p.join(tmpBase.path, '3by5-export-$dateTag.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      encoder.addDirectory(tempDir, includeDirName: false);
      encoder.close();
      _check();

      // 11. Verify ZIP
      yield const ExportProgress(fraction: 0.91, status: 'Verifying…');
      final zipFile = File(zipPath);
      if (!await zipFile.exists() || await zipFile.length() == 0) {
        throw Exception('ZIP file was not created correctly.');
      }
      _check();

      // 12. Save dialog
      yield const ExportProgress(
          fraction: 0.93, status: 'Choose where to save…');
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save 3by5 Export',
        fileName: '3by5-export-$dateTag.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      _check();

      if (savePath == null) {
        // User cancelled the dialog — clean up the assembled zip.
        try { await zipFile.delete(); } catch (_) {}
        yield const ExportProgress(
          fraction: 1.0,
          status: 'Export cancelled.',
          isCancelled: true,
        );
        return;
      }

      // 13. Move to chosen location
      yield const ExportProgress(fraction: 0.97, status: 'Saving file…');
      await zipFile.copy(savePath);
      try { await zipFile.delete(); } catch (_) {}

      // 14. Done
      final totalAtts = copiedImages + writtenEmails - missingFiles;
      yield ExportProgress(
        fraction: 1.0,
        status: 'Export complete.',
        isDone: true,
        result: ExportResult(
          taskCount: d.tasks.length,
          attachmentCount: math.max(0, totalAtts),
          missingFileCount: missingFiles,
          outputPath: savePath,
        ),
      );
    } on _Cancelled {
      yield const ExportProgress(
          fraction: 0.0, status: 'Export cancelled.', isCancelled: true);
    } catch (e, st) {
      debugPrint('ExportService error: $e\n$st');
      yield ExportProgress(
        fraction: 0.0,
        status: 'Export failed.',
        error: e.toString(),
      );
    } finally {
      if (tempDir != null) {
        try {
          if (await tempDir.exists()) await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<_D> _loadAll() async {
    // Stacks
    final stackList = await (_db.select(_db.stacks)
          ..where((s) => s.deletedAt.isNull())
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .get();
    final stacks = {for (final s in stackList) s.id: s};

    // Cards (include archived; exclude soft-deleted)
    final cardList = await (_db.select(_db.cards)
          ..where((c) => c.deletedAt.isNull()))
        .get();
    final cards = {for (final c in cardList) c.id: c};

    // Tasks
    final taskList = await (_db.select(_db.tasks)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    // Only export tasks whose parent card still exists.
    final tasks = taskList.where((t) => cards.containsKey(t.cardId)).toList();

    // Notes — exclude soft-deleted
    final noteList = await (_db.select(_db.notes)
          ..where((n) => n.deletedAt.isNull())
          ..orderBy([(n) => OrderingTerm.asc(n.createdAt)]))
        .get();
    final notesByTask = <String, List<AppNote>>{};
    for (final n in noteList) {
      notesByTask.putIfAbsent(n.taskId, () => []).add(n);
    }

    // Attachments
    final attList = await (_db.select(_db.attachments)
          ..where((a) => a.deletedAt.isNull()))
        .get();
    final attsByTask = <String, List<AppAttachment>>{};
    for (final a in attList) {
      attsByTask.putIfAbsent(a.taskId, () => []).add(a);
    }

    // Tags + task-tag pairs
    final tagList = await _db.select(_db.tags).get();
    final tagsById = {for (final t in tagList) t.id: t};
    final pairs = await _db.select(_db.taskTags).get();
    final tagIdsByTask = <String, List<String>>{};
    for (final pair in pairs) {
      tagIdsByTask.putIfAbsent(pair.taskId, () => []).add(pair.tagId);
    }

    // Board columns
    final colList = await _db.select(_db.boardColumns).get();
    final colsById = {for (final c in colList) c.id: c};

    return _D(
      stacks: stacks,
      cards: cards,
      tasks: tasks,
      notesByTask: notesByTask,
      attsByTask: attsByTask,
      tagIdsByTask: tagIdsByTask,
      tagsById: tagsById,
      colsById: colsById,
    );
  }

  // ── Archive path pre-computation ─────────────────────────────────────────────

  Map<String, String> _computeArchivePaths(_D d) {
    final result = <String, String>{}; // attachmentId → 'attachments/...'
    for (final entry in d.attsByTask.entries) {
      final taskId = entry.key;
      final task = d.tasks.where((t) => t.id == taskId).firstOrNull;
      if (task == null) continue;
      final taskSlug = _slug(task.title);
      final taskFrag = taskId.substring(0, math.min(4, taskId.length));

      for (final att in entry.value) {
        if (att.type == 'image' && att.filePath != null) {
          final basename = p.basename(att.filePath!);
          result[att.id] = 'attachments/$taskSlug-$taskFrag-$basename';
        } else if (att.type == 'emailClip') {
          final senderSlug = _senderSlug(att.emailSender ?? '');
          final date = att.emailOriginalDate ?? att.createdAt;
          final dateStr = _isoDateFmt.format(date);
          final attFrag =
              att.id.substring(0, math.min(4, att.id.length));
          result[att.id] =
              'attachments/email-from-$senderSlug-$dateStr-$attFrag.txt';
        }
      }
    }
    return result;
  }

  // ── Main CSV ─────────────────────────────────────────────────────────────────

  static const _kHeaders = [
    'Stack', 'Project', 'Card Date', 'Card Status', 'Column',
    'Task', 'Description', 'Priority', 'Due Date', 'Due Status',
    'Recurring', 'Tags', 'Completed', 'Completed Date', 'Kanban Stage',
    'Notes', 'Image Files', 'Links', 'Email Clips',
  ];

  List<int> _buildMainCsv(
      _D d, Map<String, String> archivePaths, String dateTag) {
    final buf = StringBuffer();
    buf.write(_row(_kHeaders));

    for (final task in _sortTasks(d)) {
      final card = d.cards[task.cardId];
      final stack = card != null ? d.stacks[card.stackId] : null;
      final notes = d.notesByTask[task.id] ?? [];
      final atts  = d.attsByTask[task.id] ?? [];
      final stage = task.kanbanStageId != null
          ? d.colsById[task.kanbanStageId]?.title
          : null;

      buf.write(_row([
        stack?.name,
        card?.projectTitle,
        card != null ? _dateFmt.format(card.date) : null,
        _cardStatusLabel(card?.status),
        task.columnName == 'now' ? 'Now' : 'Later',
        task.title,
        _deltaToPlain(task.description),
        _priorityLabel(task.priority),
        task.dueDate != null ? _dateFmt.format(task.dueDate!) : null,
        _dueStatus(task),
        _rruleHuman(task.rrule),
        _joinTags(d, task.id),
        task.isCompleted ? 'Yes' : 'No',
        task.completedAt != null ? _dateFmt.format(task.completedAt!) : null,
        stage,
        _joinNotes(notes),
        _joinImagePaths(atts, archivePaths),
        _joinLinks(atts),
        _joinEmailPaths(atts, archivePaths),
      ]));
    }
    return _utf8Bom(buf.toString());
  }

  // ── Summary CSV ──────────────────────────────────────────────────────────────

  static const _kSummaryHeaders = [
    'Stack', 'Total Tasks', 'Now Tasks', 'Later Tasks',
    'Completed Tasks', 'Overdue Tasks', 'Due This Week', 'No Due Date',
  ];

  List<int> _buildSummaryCsv(_D d, String dateTag) {
    final buf = StringBuffer();
    buf.write(_row(_kSummaryHeaders));

    final today = DateTime.now();
    final todayDate =
        DateTime(today.year, today.month, today.day);

    // Group tasks by stack
    final byStack = <String, List<AppTask>>{};
    for (final task in d.tasks) {
      final stackId = d.cards[task.cardId]?.stackId ?? '';
      byStack.putIfAbsent(stackId, () => []).add(task);
    }

    int totTotal = 0, totNow = 0, totLater = 0, totDone = 0,
        totOverdue = 0, totWeek = 0, totNoDue = 0;

    final sortedStacks = d.stacks.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    for (final stack in sortedStacks) {
      final tasks = byStack[stack.id] ?? [];
      final total   = tasks.length;
      final now     = tasks.where((t) => t.columnName == 'now').length;
      final later   = tasks.where((t) => t.columnName == 'later').length;
      final done    = tasks.where((t) => t.isCompleted).length;
      final overdue = tasks.where((t) => _isOverdue(t, todayDate)).length;
      final week    = tasks.where((t) => _isDueThisWeek(t, todayDate)).length;
      final noDue   = tasks.where((t) => t.dueDate == null).length;

      buf.write(_row([
        stack.name,
        '$total', '$now', '$later', '$done',
        '$overdue', '$week', '$noDue',
      ]));

      totTotal += total; totNow += now; totLater += later; totDone += done;
      totOverdue += overdue; totWeek += week; totNoDue += noDue;
    }

    buf.write(_row([
      'Total',
      '$totTotal', '$totNow', '$totLater', '$totDone',
      '$totOverdue', '$totWeek', '$totNoDue',
    ]));

    return _utf8Bom(buf.toString());
  }

  // ── README ───────────────────────────────────────────────────────────────────

  String _buildReadme(_D d, String dateTag) {
    final now = DateTime.now();
    final exportDt =
        intl.DateFormat("EEE d MMM yyyy 'at' HH:mm").format(now);
    return '''3by5 Export
Exported: $exportDt
Tasks: ${d.tasks.length}
============================================================

3by5 is a macOS task manager built around physical 3×5 index cards.
Each card holds tasks split into "Now" (do today) and "Later" (backlog).

CONTENTS
--------
3by5-export-$dateTag.csv
  Full task list. One row per task. Self-contained — no cross-referencing
  needed to understand any row.

3by5-export-$dateTag-summary.csv
  Stack-by-stack task count summary with a totals row.

attachments/
  Image files and email clip text files referenced in the main CSV.
  Paths in the CSV are relative to the zip root (e.g. attachments/photo.jpg).

attachments/manifest.json
  Machine-readable list of every exported file with type, task, and status.
  Files with "missing" status were not found on disk at export time.

OPENING THE CSV IN EXCEL
------------------------
The file uses UTF-8 with BOM encoding — Excel opens it correctly without
any import wizard. Just double-click. For Numbers, import it as CSV with
UTF-8 encoding.

Suggested first filters: Stack, Column, Due Status, Priority.

COLUMN DEFINITIONS
------------------
Stack           Your stack (project or context container)
Project         Card project title, if set
Card Date       The date on the card header
Card Status     Active or Archived
Column          Now (urgent/today) or Later (backlog)
Task            Task title
Description     Task description, plain text (rich formatting stripped)
Priority        High, Normal, or Low
Due Date        When the task is due
Due Status      Overdue / Due Today / Due This Week / Upcoming (blank if no date)
Recurring       Recurrence pattern if set (Daily, Weekly, Monthly, etc.)
Tags            All tags, semicolon-separated, prefixed with @
Completed       Yes or No
Completed Date  When the task was marked complete (blank for tasks completed
                before app version 1.0.0 — completion timestamps were added
                in that version)
Kanban Stage    Board column name if the task is on a kanban board
Notes           All notes concatenated, each prefixed with [Day Date Time]
Image Files     Relative paths to exported images in attachments/
Links           URLs from saved link attachments
Email Clips     Relative paths to exported email text files in attachments/

EMAIL CLIPS
-----------
Email clips contain the sender, date, subject, and the first five lines
of the original email body — that's the amount stored when the clip was
saved in 3by5.

SUPPORT
-------
For help: https://github.com/your-org/3by5
''';
  }

  // ── Email clip reconstruction ─────────────────────────────────────────────

  String _reconstructEmailClip(AppAttachment att) {
    final lines = <String>[];
    if ((att.emailSender ?? '').isNotEmpty) lines.add('From: ${att.emailSender}');
    final date = att.emailOriginalDate ?? att.createdAt;
    lines.add('Date: ${intl.DateFormat('EEE d MMM yyyy HH:mm').format(date)}');
    if ((att.emailSubject ?? '').isNotEmpty) lines.add('Subject: ${att.emailSubject}');
    if ((att.emailSourceClient ?? '').isNotEmpty) {
      lines.add('Client: ${att.emailSourceClient}');
    }
    lines.add('');
    if ((att.emailBodySnippet ?? '').isNotEmpty) {
      lines.add(att.emailBodySnippet!);
      lines.add('');
      lines.add(
          '[Note: Only the first 5 lines of the email body were stored.]');
    }
    return lines.join('\n');
  }

  // ── Sorting ──────────────────────────────────────────────────────────────────

  List<AppTask> _sortTasks(_D d) {
    final tasks = List<AppTask>.from(d.tasks);
    final priOrder = {'high': 0, 'normal': 1, 'low': 2};
    final colOrder = {'now': 0, 'later': 1};
    tasks.sort((a, b) {
      final cardA = d.cards[a.cardId];
      final cardB = d.cards[b.cardId];
      // 1. Stack name
      final sA = d.stacks[cardA?.stackId]?.name ?? '';
      final sB = d.stacks[cardB?.stackId]?.name ?? '';
      var c = sA.compareTo(sB);
      if (c != 0) return c;
      // 2. Card date ascending
      c = (cardA?.date ?? DateTime(2000))
          .compareTo(cardB?.date ?? DateTime(2000));
      if (c != 0) return c;
      // 3. Column: now before later
      c = (colOrder[a.columnName] ?? 2).compareTo(colOrder[b.columnName] ?? 2);
      if (c != 0) return c;
      // 4. Priority: high → normal → low
      c = (priOrder[a.priority] ?? 1).compareTo(priOrder[b.priority] ?? 1);
      if (c != 0) return c;
      // 5. Title
      return a.title.compareTo(b.title);
    });
    return tasks;
  }

  // ── Cell helpers ─────────────────────────────────────────────────────────────

  String _joinTags(_D d, String taskId) {
    final ids = d.tagIdsByTask[taskId] ?? [];
    if (ids.isEmpty) return '';
    final names = ids
        .map((id) => d.tagsById[id]?.name)
        .whereType<String>()
        .map((n) => '@$n')
        .toList()
      ..sort();
    return names.join('; ');
  }

  String _joinNotes(List<AppNote> notes) {
    if (notes.isEmpty) return '';
    return notes.map((n) {
      final ts = '[${_noteFmt.format(n.createdAt)}]';
      final body = _deltaToPlain(n.body);
      return body.isEmpty ? ts : '$ts $body';
    }).join('\n');
  }

  String _joinImagePaths(
      List<AppAttachment> atts, Map<String, String> paths) {
    final list = atts
        .where((a) => a.type == 'image' && paths.containsKey(a.id))
        .map((a) => paths[a.id]!)
        .toList();
    return list.join('; ');
  }

  String _joinLinks(List<AppAttachment> atts) {
    final urls =
        atts.where((a) => a.type == 'link' && (a.url ?? '').isNotEmpty)
            .map((a) => a.url!)
            .toList();
    return urls.join('; ');
  }

  String _joinEmailPaths(
      List<AppAttachment> atts, Map<String, String> paths) {
    final list = atts
        .where((a) => a.type == 'emailClip' && paths.containsKey(a.id))
        .map((a) => paths[a.id]!)
        .toList();
    return list.join('; ');
  }

  // ── Pure helpers ──────────────────────────────────────────────────────────────

  static String _deltaToPlain(String? json) {
    if (json == null || json.isEmpty) return '';
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return '';
      final ops = decoded['ops'];
      if (ops is! List) return '';
      final buf = StringBuffer();
      for (final op in ops) {
        if (op is Map) {
          final ins = op['insert'];
          if (ins is String) buf.write(ins);
        }
      }
      return buf.toString().trim();
    } catch (_) {
      return '';
    }
  }

  static String _priorityLabel(String p) => switch (p) {
        'high' => 'High',
        'low'  => 'Low',
        _      => 'Normal',
      };

  static String _cardStatusLabel(String? s) => switch (s) {
        'archived' => 'Archived',
        _          => 'Active',
      };

  static String _dueStatus(AppTask task) {
    if (task.dueDate == null) return '';
    if (task.isCompleted) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due   = DateTime(
        task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
    if (due.isBefore(today)) return 'Overdue';
    if (due == today)        return 'Due Today';
    if (due.isBefore(today.add(const Duration(days: 8)))) {
      return 'Due This Week';
    }
    return 'Upcoming';
  }

  static bool _isOverdue(AppTask t, DateTime today) {
    if (t.dueDate == null || t.isCompleted) return false;
    return DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day)
        .isBefore(today);
  }

  static bool _isDueThisWeek(AppTask t, DateTime today) {
    if (t.dueDate == null || t.isCompleted) return false;
    final d = DateTime(
        t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
    return !d.isBefore(today) &&
        d.isBefore(today.add(const Duration(days: 8)));
  }

  static String _rruleHuman(String? rrule) {
    if (rrule == null || rrule.isEmpty) return '';
    final parts = <String, String>{};
    for (final seg in rrule.toUpperCase().split(';')) {
      final kv = seg.split('=');
      if (kv.length == 2) parts[kv[0]] = kv[1];
    }
    final freq     = parts['FREQ'] ?? '';
    final interval = int.tryParse(parts['INTERVAL'] ?? '1') ?? 1;
    return switch (freq) {
      'DAILY'  when interval == 1 => 'Daily',
      'DAILY'                     => 'Every $interval days',
      'WEEKLY' when interval == 1 => 'Weekly',
      'WEEKLY'                    => 'Every $interval weeks',
      'MONTHLY' when interval == 3 => 'Quarterly',
      'MONTHLY' when interval == 1 => 'Monthly',
      'MONTHLY'                    => 'Every $interval months',
      'YEARLY' when interval == 1 => 'Yearly',
      'YEARLY'                    => 'Every $interval years',
      _                           => '',
    };
  }

  // ── Slug helpers ──────────────────────────────────────────────────────────────

  static String _slug(String text, {int max = 40}) {
    var s = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (s.length > max) {
      s = s.substring(0, max).replaceAll(RegExp(r'-+$'), '');
    }
    return s.isEmpty ? 'task' : s;
  }

  static String _senderSlug(String sender) {
    final clean = sender
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim()
        .replaceAll('@', '-')
        .replaceAll('.', '-');
    return _slug(clean, max: 30);
  }

  // ── CSV encoding ──────────────────────────────────────────────────────────────

  static String _cell(String? v) {
    final s = (v ?? '').replaceAll('"', '""');
    return '"$s"';
  }

  static String _row(List<String?> cells) =>
      '${cells.map(_cell).join(',')}\r\n';

  static List<int> _utf8Bom(String s) =>
      [0xEF, 0xBB, 0xBF, ...utf8.encode(s)];
}
