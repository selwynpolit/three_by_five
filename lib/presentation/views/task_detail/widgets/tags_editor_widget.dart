import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/database/app_database.dart';
import '../../../providers/tag_providers.dart';

class TagsEditorWidget extends ConsumerStatefulWidget {
  const TagsEditorWidget({
    super.key,
    required this.taskId,
    required this.tagsAsync,
  });

  final String taskId;
  final AsyncValue<List<AppTag>> tagsAsync;

  @override
  ConsumerState<TagsEditorWidget> createState() =>
      _TagsEditorWidgetState();
}

class _TagsEditorWidgetState extends ConsumerState<TagsEditorWidget> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _addTag(String name) async {
    final trimmed = name.trim().toLowerCase();
    if (trimmed.isEmpty) return;
    _controller.clear();
    await ref
        .read(tagRepositoryProvider)
        .addTagNameToTask(widget.taskId, trimmed);
  }

  Future<void> _removeTag(AppTag tag) async {
    await ref
        .read(tagRepositoryProvider)
        .removeFromTask(widget.taskId, tag.id);
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.tagsAsync.valueOrNull ?? [];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Existing tags
        for (final tag in tags)
          _TagChip(
            label: tag.name,
            onRemove: () => _removeTag(tag),
          ),

        // Add input
        if (_editing)
          SizedBox(
            width: 120,
            height: 26,
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey ==
                          LogicalKeyboardKey.enter ||
                      event.logicalKey ==
                          LogicalKeyboardKey.comma) {
                    _addTag(_controller.text);
                    setState(() => _editing = false);
                  } else if (event.logicalKey ==
                      LogicalKeyboardKey.escape) {
                    setState(() {
                      _editing = false;
                      _controller.clear();
                    });
                  }
                }
              },
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                onSubmitted: (v) {
                  _addTag(v);
                  setState(() => _editing = false);
                },
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'tag name',
                  hintStyle: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textDisabled),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                        color: AppColors.accent, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                        color: AppColors.cardBorder, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                        color: AppColors.accent, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.canvas,
                ),
              ),
            ),
          )
        else
          // "Add tag" button
          _AddTagButton(
            onTap: () => setState(() => _editing = true),
          ),
      ],
    );
  }
}

class _TagChip extends StatefulWidget {
  const _TagChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  State<_TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<_TagChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.tagBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.tagText,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (_hovered) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.onRemove,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: const Icon(Icons.close,
                      size: 11, color: AppColors.tagText),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddTagButton extends StatefulWidget {
  const _AddTagButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AddTagButton> createState() => _AddTagButtonState();
}

class _AddTagButtonState extends State<_AddTagButton> {
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
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.divider : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.cardBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 12,
                  color: AppColors.textTertiary),
              const SizedBox(width: 3),
              Text(
                'Add tag',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
