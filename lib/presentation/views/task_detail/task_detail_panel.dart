import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/services/email_clip_service.dart';
import '../../../domain/services/url_fetch_service.dart';
import '../../providers/detail_providers.dart';
import '../../providers/tag_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/ui_state_providers.dart';
import '../../utils/quill_utils.dart';
import 'widgets/attachments_section_widget.dart';
import 'widgets/description_editor_widget.dart';
import 'widgets/note_composer_widget.dart';
import 'widgets/notes_feed_widget.dart';
import 'widgets/tags_editor_widget.dart';
import 'widgets/task_meta_widget.dart';

class TaskDetailPanel extends ConsumerStatefulWidget {
  const TaskDetailPanel({super.key, required this.taskId});
  final String taskId;

  @override
  ConsumerState<TaskDetailPanel> createState() =>
      _TaskDetailPanelState();
}

class _TaskDetailPanelState extends ConsumerState<TaskDetailPanel> {
  final _titleController = TextEditingController();
  final _noteFocusNode = FocusNode();
  QuillController? _quillController;
  QuillController? _noteQuillController;
  Timer? _debounce;
  bool _ready = false;
  bool _initializing = false;

  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleEscKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleEscKey);
    _debounce?.cancel();
    _titleController.dispose();
    _noteFocusNode.dispose();
    _quillController?.dispose();
    _noteQuillController?.dispose();
    super.dispose();
  }

  bool _handleEscKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    final noteCtrl = _noteQuillController;
    final hasNoteContent = noteCtrl != null && noteCtrl.document.length > 1;
    if (hasNoteContent) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showEscDialog();
      });
      return true;
    }
    return false; // let global handler close normally
  }

  Future<void> _showEscDialog() async {
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved note'),
        content: const Text('You have unsaved note content. Save before closing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (result == true) await _submitNote();
    ref.read(selectedTaskIdProvider.notifier).select(null);
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  void _onFirstData(AppTask task) {
    _titleController.text = task.title;
    _titleController.addListener(_scheduleTitleSave);

    _quillController = quillControllerFromBody(task.description);
    _quillController!.addListener(_scheduleDescSave);

    _noteQuillController = quillControllerFromBody(null);

    setState(() => _ready = true);
  }

  // ── Auto-save ──────────────────────────────────────────────────────────────

  void _scheduleTitleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final title = _titleController.text.trim();
      if (title.isEmpty) return;
      await ref
          .read(taskRepositoryProvider)
          .update(id: widget.taskId, title: title);
    });
  }

  void _forceSaveAndClose() {
    _debounce?.cancel();
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      ref.read(taskRepositoryProvider).update(id: widget.taskId, title: title);
    }
    ref.read(selectedTaskIdProvider.notifier).select(null);
  }

  void _scheduleDescSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      final ctrl = _quillController;
      if (ctrl == null) return;
      final isEmpty = ctrl.document.length <= 1;
      final json = isEmpty
          ? null
          : jsonEncode(ctrl.document.toDelta().toJson());
      await ref
          .read(taskRepositoryProvider)
          .update(id: widget.taskId, description: json);
    });
  }

  // ── Note submission ────────────────────────────────────────────────────────

  void _clearNoteComposer() {
    final old = _noteQuillController;
    setState(() => _noteQuillController = quillControllerFromBody(null));
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  Future<void> _submitNote() async {
    final ctrl = _noteQuillController;
    if (ctrl == null) return;
    if (ctrl.document.length <= 1) return; // empty (only trailing newline)

    final plainText = ctrl.document.toPlainText().trim();
    if (plainText.isEmpty) return;

    // Detect email clip
    final emailSvc = EmailClipService();
    if (emailSvc.looksLikeEmail(plainText)) {
      final clip = emailSvc.parse(plainText)!;
      await ref.read(attachmentRepositoryProvider).addEmailClip(
            taskId: widget.taskId,
            subject: clip.subject,
            sender: clip.sender,
            bodySnippet: clip.bodySnippet,
          );
      _clearNoteComposer();
      return;
    }

    // Check if the entire content is a plain URL
    final urlPattern = RegExp(r'^https?://\S+$', caseSensitive: false);
    if (urlPattern.hasMatch(plainText)) {
      await _addLinkAttachment(plainText);
      _clearNoteComposer();
      return;
    }

    final json =
        jsonEncode(ctrl.document.toDelta().toJson());
    await ref
        .read(noteRepositoryProvider)
        .create(taskId: widget.taskId, body: json);
    _clearNoteComposer();
  }

  Future<void> _submitNoteAndClose() async {
    await _submitNote();
    if (mounted) ref.read(selectedTaskIdProvider.notifier).select(null);
  }

  Future<void> _addLinkAttachment(String url) async {
    final result = await UrlFetchService().fetch(url);
    await ref.read(attachmentRepositoryProvider).addLink(
          taskId: widget.taskId,
          url: url,
          title: result.title,
          faviconUrl: result.faviconUrl,
        );
  }

  Future<void> _onImageDropped(DropDoneDetails detail) async {
    final appDir = await getApplicationSupportDirectory();
    final attachDir =
        Directory(p.join(appDir.path, 'attachments'));
    await attachDir.create(recursive: true);

    for (final item in detail.files) {
      final src = item.path;
      final ext = p.extension(src).toLowerCase();
      if (!['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic']
          .contains(ext)) {
        continue;
      }

      final destName = '${_uuid.v4()}$ext';
      final destPath = p.join(attachDir.path, destName);
      await File(src).copy(destPath);
      await ref
          .read(attachmentRepositoryProvider)
          .addImage(taskId: widget.taskId, filePath: destPath);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskByIdProvider(widget.taskId));
    final notesAsync =
        ref.watch(notesForTaskProvider(widget.taskId));
    final attachmentsAsync =
        ref.watch(attachmentsForTaskProvider(widget.taskId));
    final tagsAsync =
        ref.watch(tagsForTaskProvider(widget.taskId));

    return taskAsync.when(
      loading: () => const _PanelSkeleton(),
      error: (e, _) => _PanelError('$e'),
      data: (task) {
        if (task == null) return const SizedBox.shrink();

        if (!_ready && !_initializing) {
          _initializing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _onFirstData(task);
          });
          return const _PanelSkeleton();
        }

        if (!_ready) return const _PanelSkeleton();

        return _buildContent(
          context,
          task,
          notesAsync,
          attachmentsAsync,
          tagsAsync,
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppTask task,
    AsyncValue<List<AppNote>> notesAsync,
    AsyncValue<List<AppAttachment>> attachmentsAsync,
    AsyncValue<List<AppTag>> tagsAsync,
  ) {
    return DropTarget(
      onDragDone: _onImageDropped,
      child: Material(
        color: AppColors.cardSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Panel header ───────────────────────────────────────
            _PanelHeader(
              onClose: () => ref
                  .read(selectedTaskIdProvider.notifier)
                  .select(null),
              isCompleted: task.isCompleted,
              onToggleComplete: () => ref
                  .read(taskRepositoryProvider)
                  .markComplete(task.id,
                      completed: !task.isCompleted),
            ),

            // ── Scrollable body ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    // Title — Enter saves and closes the panel.
                    CallbackShortcuts(
                      bindings: {
                        const SingleActivator(
                                LogicalKeyboardKey.enter):
                            _forceSaveAndClose,
                      },
                      child: TextField(
                        controller: _titleController,
                        style: AppTypography.textTheme.headlineMedium
                            ?.copyWith(
                          color: task.isCompleted
                              ? AppColors.textCompleted
                              : AppColors.textPrimary,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: AppColors.textCompleted,
                        ),
                        maxLines: null,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Priority + due date
                    TaskMetaWidget(
                      task: task,
                      onPriorityChanged: (p) => ref
                          .read(taskRepositoryProvider)
                          .update(
                              id: task.id, priority: p),
                      onDueDateChanged: (d) => ref
                          .read(taskRepositoryProvider)
                          .updateDueDate(task.id, d),
                    ),

                    const SizedBox(height: 10),

                    // Tags
                    TagsEditorWidget(
                      taskId: task.id,
                      tagsAsync: tagsAsync,
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Description label
                    Text(
                      'DESCRIPTION',
                      style:
                          Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),

                    // Quill editor
                    CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
                          // Force-save description and close
                          _debounce?.cancel();
                          final ctrl = _quillController;
                          if (ctrl != null && ctrl.document.length > 1) {
                            final json = jsonEncode(ctrl.document.toDelta().toJson());
                            ref.read(taskRepositoryProvider).update(id: widget.taskId, description: json);
                          }
                          ref.read(selectedTaskIdProvider.notifier).select(null);
                        },
                      },
                      child: DescriptionEditorWidget(controller: _quillController!),
                    ),

                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Attachments
                    AttachmentsSectionWidget(
                      taskId: task.id,
                      attachmentsAsync: attachmentsAsync,
                    ),

                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Notes label
                    Text(
                      'NOTES',
                      style:
                          Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),

                    // Notes feed
                    NotesFeedWidget(
                      notesAsync: notesAsync,
                      onAddNote: () => _noteFocusNode.requestFocus(),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // ── Note composer ──────────────────────────────────────
            NoteComposerWidget(
              controller: _noteQuillController!,
              focusNode: _noteFocusNode,
              onSubmit: _submitNote,
              onCmdReturn: _submitNoteAndClose,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Panel header ───────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.onClose,
    required this.isCompleted,
    required this.onToggleComplete,
  });

  final VoidCallback onClose;
  final bool isCompleted;
  final VoidCallback onToggleComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Complete toggle
          Tooltip(
            message: isCompleted ? 'Mark incomplete' : 'Mark complete',
            child: _IconBtn(
              icon: isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isCompleted
                  ? AppColors.accent
                  : AppColors.textTertiary,
              onTap: onToggleComplete,
            ),
          ),
          const Spacer(),
          // Close
          Tooltip(
            message: 'Close (Esc)',
            child: _IconBtn(
              icon: Icons.close,
              color: AppColors.textTertiary,
              onTap: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
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
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.divider
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon, size: 18, color: widget.color),
        ),
      ),
    );
  }
}

// ── Skeleton ───────────────────────────────────────────────────────────────────

class _PanelSkeleton extends StatelessWidget {
  const _PanelSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: AppColors.cardSurface,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonLine(width: 280, height: 22),
            SizedBox(height: 12),
            _SkeletonLine(width: 180, height: 14),
            SizedBox(height: 8),
            _SkeletonLine(width: 120, height: 14),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _PanelError extends StatelessWidget {
  const _PanelError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardSurface,
      child: Center(
        child: Text(message,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textTertiary)),
      ),
    );
  }
}
