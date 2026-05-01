import 'dart:async';
import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
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
import 'widgets/attachments_section_widget.dart';
import 'widgets/description_editor_widget.dart';
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
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _noteFocusNode.dispose();
    _quillController?.dispose();
    _noteQuillController?.dispose();
    super.dispose();
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  void _onFirstData(AppTask task) {
    _titleController.text = task.title;
    _titleController.addListener(_scheduleTitleSave);

    _quillController = _createQuill(task.description);
    _quillController!.addListener(_scheduleDescSave);

    _noteQuillController = QuillController.basic();

    setState(() => _ready = true);
  }

  QuillController _createQuill(String? description) {
    if (description == null || description.isEmpty) {
      return QuillController.basic();
    }
    try {
      final ops = jsonDecode(description) as List<dynamic>;
      return QuillController(
        document: Document.fromJson(ops),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (_) {
      return QuillController.basic();
    }
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
    setState(() => _noteQuillController = QuillController.basic());
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
                    // Title
                    TextField(
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
                      textInputAction: TextInputAction.newline,
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
                    DescriptionEditorWidget(
                      controller: _quillController!,
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
                    NotesFeedWidget(notesAsync: notesAsync),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // ── Note composer ──────────────────────────────────────
            _NoteComposer(
              controller: _noteQuillController!,
              focusNode: _noteFocusNode,
              onSubmit: _submitNote,
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

// ── Note composer (Quill-based) ────────────────────────────────────────────────

class _NoteComposer extends StatefulWidget {
  const _NoteComposer({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  State<_NoteComposer> createState() => _NoteComposerState();
}

class _NoteComposerState extends State<_NoteComposer> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_NoteComposer old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() =>
      setState(() => _focused = widget.focusNode.hasFocus);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(
            top: BorderSide(color: AppColors.divider, width: 0.5)),
        color: AppColors.cardSurface,
      ),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, meta: true):
              widget.onSubmit,
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toolbar — animates in when editor is focused.
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 160),
              crossFadeState: _focused
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: QuillSimpleToolbar(
                  controller: widget.controller,
                  config: const QuillSimpleToolbarConfig(
                    showDividers: false,
                    showFontFamily: false,
                    showFontSize: false,
                    showBoldButton: true,
                    showItalicButton: true,
                    showSmallButton: false,
                    showUnderLineButton: false,
                    showStrikeThrough: false,
                    showInlineCode: false,
                    showColorButton: false,
                    showBackgroundColorButton: false,
                    showClearFormat: false,
                    showAlignmentButtons: false,
                    showLeftAlignment: false,
                    showCenterAlignment: false,
                    showRightAlignment: false,
                    showJustifyAlignment: false,
                    showHeaderStyle: false,
                    showListNumbers: true,
                    showListBullets: true,
                    showListCheck: false,
                    showCodeBlock: false,
                    showQuote: false,
                    showIndent: false,
                    showLink: false,
                    showUndo: true,
                    showRedo: false,
                    showDirection: false,
                    showSearchButton: false,
                    showSubscript: false,
                    showSuperscript: false,
                    multiRowsDisplay: false,
                    toolbarSize: 28,
                    toolbarIconAlignment: WrapAlignment.start,
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),

            // Editor
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              constraints:
                  const BoxConstraints(minHeight: 52, maxHeight: 130),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _focused
                      ? AppColors.accent
                      : AppColors.cardBorder,
                  width: _focused ? 1 : 0.5,
                ),
              ),
              child: QuillEditor.basic(
                controller: widget.controller,
                focusNode: widget.focusNode,
                config: QuillEditorConfig(
                  placeholder: 'Add a note… (⌘↵ to save)',
                  autoFocus: false,
                  expands: false,
                  scrollable: true,
                  padding: EdgeInsets.zero,
                  customStyles: DefaultStyles(
                    paragraph: DefaultTextBlockStyle(
                      AppTypography.textTheme.bodyMedium!.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                      HorizontalSpacing.zero,
                      VerticalSpacing.zero,
                      VerticalSpacing.zero,
                      null,
                    ),
                    placeHolder: DefaultTextBlockStyle(
                      AppTypography.textTheme.bodyMedium!.copyWith(
                        color: AppColors.textDisabled,
                        height: 1.5,
                      ),
                      HorizontalSpacing.zero,
                      VerticalSpacing.zero,
                      VerticalSpacing.zero,
                      null,
                    ),
                  ),
                ),
              ),
            ),

            // Submit row — visible when focused.
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              child: _focused
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '⌘↵ to save',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: AppColors.textDisabled),
                          ),
                          _SaveButton(onTap: widget.onSubmit),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatefulWidget {
  const _SaveButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.accent : AppColors.accentLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Save',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      _hovered ? AppColors.textInverse : AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
          ),
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
