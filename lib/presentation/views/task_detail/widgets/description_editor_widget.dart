import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class DescriptionEditorWidget extends StatefulWidget {
  const DescriptionEditorWidget({super.key, required this.controller});
  final QuillController controller;

  @override
  State<DescriptionEditorWidget> createState() =>
      _DescriptionEditorWidgetState();
}

class _DescriptionEditorWidgetState
    extends State<DescriptionEditorWidget> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Minimal toolbar — appears only when editor is focused
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 160),
          crossFadeState: _focused
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: QuillSimpleToolbar(
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
              toolbarSize: 32,
              toolbarIconAlignment: WrapAlignment.start,
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),

        // Editor
        Container(
          constraints: const BoxConstraints(minHeight: 80),
          child: QuillEditor.basic(
            controller: widget.controller,
            focusNode: _focusNode,
            config: QuillEditorConfig(
              placeholder: 'Add a description…',
              autoFocus: false,
              expands: false,
              scrollable: false,
              padding: EdgeInsets.zero,
              customStyles: DefaultStyles(
                paragraph: DefaultTextBlockStyle(
                  AppTypography.textTheme.bodyMedium!.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.55,
                  ),
                  HorizontalSpacing.zero,
                  VerticalSpacing.zero,
                  VerticalSpacing.zero,
                  null,
                ),
                placeHolder: DefaultTextBlockStyle(
                  AppTypography.textTheme.bodyMedium!.copyWith(
                    color: AppColors.textDisabled,
                    height: 1.55,
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
      ],
    );
  }
}
