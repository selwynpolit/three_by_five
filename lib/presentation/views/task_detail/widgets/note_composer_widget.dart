import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../utils/quill_image_embed.dart';

/// Fixed-bottom Quill editor for composing new notes.
///
/// Supports inline image insertion via drag-and-drop or the photo button.
/// The toolbar animates in when the editor gains focus.
/// ⌘↵ (or the Save button) fires [onSubmit].
class NoteComposerWidget extends StatefulWidget {
  const NoteComposerWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    this.onCmdReturn,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback? onCmdReturn;

  @override
  State<NoteComposerWidget> createState() => _NoteComposerWidgetState();
}

class _NoteComposerWidgetState extends State<NoteComposerWidget> {
  bool _focused = false;
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(NoteComposerWidget old) {
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

  void _onFocus() {
    if (widget.focusNode.hasFocus) {
      setState(() => _focused = true);
    } else {
      // Delay hiding so a Save button tap can register before the row
      // disappears (clicking the button removes focus from the editor first).
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _focused = false);
      });
    }
  }

  // ── Image insertion ──────────────────────────────────────────────────────────

  Future<void> _onImageDropped(DropDoneDetails detail) async {
    for (final file in detail.files) {
      final ext = p.extension(file.path).toLowerCase();
      if (!['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic']
          .contains(ext)) { continue; }
      await _insertImageFromPath(file.path);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    await _insertImageFromPath(path);
  }

  Future<void> _insertImageFromPath(String srcPath) async {
    final appDir = await getApplicationSupportDirectory();
    final attachDir = Directory(p.join(appDir.path, 'attachments'));
    await attachDir.create(recursive: true);
    final ext = p.extension(srcPath).toLowerCase();
    final destPath = p.join(attachDir.path, '${_uuid.v4()}$ext');
    await File(srcPath).copy(destPath);
    _insertEmbed(destPath);
  }

  void _insertEmbed(String path) {
    final ctrl = widget.controller;
    final index = ctrl.selection.baseOffset.clamp(0, ctrl.document.length - 1);
    final length = (ctrl.selection.extentOffset - ctrl.selection.baseOffset)
        .clamp(0, ctrl.document.length - index);
    ctrl.replaceText(index, length, BlockEmbed.image(path), null);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border:
            Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        color: AppColors.cardSurface,
      ),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, meta: true):
              widget.onCmdReturn ?? widget.onSubmit,
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toolbar — slides in when focused.
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

            // Editor with drag-drop image support.
            DropTarget(
              onDragDone: _onImageDropped,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                constraints:
                    const BoxConstraints(minHeight: 52, maxHeight: 130),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
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
                    embedBuilders: const [QuillImageEmbedBuilder()],
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
            ),

            // Submit row — visible when focused.
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              child: _focused
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          // Image insert button
                          Tooltip(
                            message: 'Insert image',
                            waitDuration:
                                const Duration(milliseconds: 600),
                            child: _IconBtn(
                              icon: Icons.image_outlined,
                              onTap: _pickImage,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '⌘↵ to save',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                    color: AppColors.textDisabled),
                          ),
                          const SizedBox(width: 8),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.accent : AppColors.accentLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Save',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _hovered
                      ? AppColors.textInverse
                      : AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
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
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.divider : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon,
              size: 16,
              color: _hovered ? AppColors.accent : AppColors.textTertiary),
        ),
      ),
    );
  }
}
