import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/database/app_database.dart';
import '../../../providers/detail_providers.dart';

class NotesFeedWidget extends StatelessWidget {
  const NotesFeedWidget({super.key, required this.notesAsync});
  final AsyncValue<List<AppNote>> notesAsync;

  @override
  Widget build(BuildContext context) {
    return notesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (notes) {
        if (notes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No notes yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textDisabled,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: notes
              .map((note) => _NoteItem(key: ValueKey(note.id), note: note))
              .toList(),
        );
      },
    );
  }
}

// ── Note item ─────────────────────────────────────────────────────────────────

class _NoteItem extends ConsumerStatefulWidget {
  const _NoteItem({super.key, required this.note});
  final AppNote note;

  @override
  ConsumerState<_NoteItem> createState() => _NoteItemState();
}

class _NoteItemState extends ConsumerState<_NoteItem> {
  late QuillController _controller;
  final _focusNode = FocusNode();
  bool _editing = false;
  bool _hovered = false;

  static final _timeFmt = DateFormat('d MMM yyyy · h:mm a');

  // Parses Quill Delta JSON or falls back to wrapping plain text.
  // Created as read-only by default (view mode).
  static QuillController _parse(String body) {
    try {
      final ops = jsonDecode(body) as List;
      return QuillController(
        document: Document.fromJson(ops),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (_) {
      // Plain text — represent as a minimal Delta JSON structure.
      final text = body.isEmpty ? '\n' : '$body\n';
      return QuillController(
        document: Document.fromJson([
          {'insert': text}
        ]),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = _parse(widget.note.body);
  }

  @override
  void didUpdateWidget(_NoteItem old) {
    super.didUpdateWidget(old);
    if (old.note.body != widget.note.body && !_editing) {
      _controller.dispose();
      _controller = _parse(widget.note.body);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEdit() {
    _controller.readOnly = false;
    setState(() => _editing = true);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _cancelEdit() {
    _controller.dispose();
    _controller = _parse(widget.note.body); // re-parses as readOnly:true
    setState(() => _editing = false);
  }

  Future<void> _save() async {
    final isEmpty = _controller.document.length <= 1;
    if (!isEmpty) {
      final json =
          jsonEncode(_controller.document.toDelta().toJson());
      await ref
          .read(noteRepositoryProvider)
          .update(widget.note.id, body: json);
    }
    _controller.readOnly = true;
    setState(() => _editing = false);
  }

  Future<void> _delete() async {
    await ref.read(noteRepositoryProvider).delete(widget.note.id);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header row ───────────────────────────────────────────
            Row(
              children: [
                Text(
                  _timeFmt.format(widget.note.createdAt),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w400,
                      ),
                ),
                const Spacer(),
                if (!_editing)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _hovered ? 1.0 : 0.0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionBtn(
                          icon: Icons.edit_outlined,
                          tooltip: 'Edit',
                          onTap: _startEdit,
                        ),
                        const SizedBox(width: 2),
                        _ActionBtn(
                          icon: Icons.delete_outlined,
                          tooltip: 'Delete',
                          destructive: true,
                          onTap: _delete,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),

            // ── Toolbar (edit mode only) ──────────────────────────────
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: QuillSimpleToolbar(
                  controller: _controller,
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

            // ── Note bubble ──────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _editing ? AppColors.accent : AppColors.divider,
                  width: _editing ? 1 : 0.5,
                ),
              ),
              child: QuillEditor.basic(
                controller: _controller,
                focusNode: _focusNode,
                config: QuillEditorConfig(
                  autoFocus: false,
                  expands: false,
                  scrollable: false,
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
                  ),
                ),
              ),
            ),

            // ── Edit actions ─────────────────────────────────────────
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _cancelEdit,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.tonal(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Small action button ───────────────────────────────────────────────────────

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool destructive;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.destructive
        ? AppColors.overdueText
        : AppColors.textTertiary;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _hovered
                  ? color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(widget.icon, size: 13, color: color),
          ),
        ),
      ),
    );
  }
}
