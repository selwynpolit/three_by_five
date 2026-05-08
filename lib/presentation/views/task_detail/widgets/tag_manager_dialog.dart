import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/database/app_database.dart';
import '../../../providers/tag_providers.dart';

// 7-color palette (non-null entries matching _TagChip._palette)
const _kPalette = <Color>[
  Color(0xFFD64545), // red
  Color(0xFFE8873A), // orange
  Color(0xFFCBAF26), // yellow
  Color(0xFF4A7C59), // green
  Color(0xFF3D5A80), // blue
  Color(0xFF7B4F9E), // purple
  Color(0xFF8A4A6B), // pink
];

class TagManagerDialog extends ConsumerStatefulWidget {
  const TagManagerDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
        context: context,
        builder: (_) => const Dialog(
          insetPadding: EdgeInsets.all(40),
          child: SizedBox(
            width: 480,
            height: 560,
            child: TagManagerDialog(),
          ),
        ),
      );

  @override
  ConsumerState<TagManagerDialog> createState() => _TagManagerDialogState();
}

class _TagManagerDialogState extends ConsumerState<TagManagerDialog> {
  // Tags selected for merging
  final _selected = <String>{};

  // Per-tag editing state
  final _editingId = <String, bool>{};
  final _editControllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _editControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(AppTag tag) {
    return _editControllers.putIfAbsent(
        tag.id, () => TextEditingController(text: tag.name));
  }

  Future<void> _deleteTag(BuildContext ctx, AppTag tag) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete tag'),
        content: Text(
            'Delete "${tag.name}"? It will be removed from all tasks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(tagRepositoryProvider).deleteTag(tag.id);
      setState(() {
        _selected.remove(tag.id);
        _editControllers.remove(tag.id)?.dispose();
        _editingId.remove(tag.id);
      });
    }
  }

  Future<void> _mergeTags(BuildContext ctx, List<AppTag> allTags) async {
    if (_selected.length != 2) return;
    final ids = _selected.toList();
    final tagA = allTags.firstWhere((t) => t.id == ids[0]);
    final tagB = allTags.firstWhere((t) => t.id == ids[1]);

    final keepId = await showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Merge tags — which name to keep?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(tagA.name),
              onTap: () => Navigator.pop(ctx, tagA.id),
            ),
            ListTile(
              title: Text(tagB.name),
              onTap: () => Navigator.pop(ctx, tagB.id),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (keepId == null) return;
    final removeId = keepId == tagA.id ? tagB.id : tagA.id;
    await ref.read(tagRepositoryProvider).mergeTagInto(keepId, removeId);
    setState(() {
      _selected.clear();
      _editControllers.remove(removeId)?.dispose();
      _editingId.remove(removeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(allTagsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title row
          Row(
            children: [
              Text(
                'Manage Tags',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.textTertiary,
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 16,
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 4),

          // Tag list
          Expanded(
            child: tagsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (tags) {
                if (tags.isEmpty) {
                  return Center(
                    child: Text(
                      'No tags yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textDisabled,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: tags.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 8, endIndent: 8),
                  itemBuilder: (ctx, i) {
                    final tag = tags[i];
                    final isEditing = _editingId[tag.id] == true;
                    final isChecked = _selected.contains(tag.id);
                    final ctrl = _controllerFor(tag);
                    // Sync controller text with current tag name when not editing
                    if (!isEditing && ctrl.text != tag.name) {
                      ctrl.text = tag.name;
                    }
                    final dotColor = tag.color != null
                        ? Color(tag.color!)
                        : AppColors.textDisabled;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          // Merge checkbox
                          Checkbox(
                            value: isChecked,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(tag.id);
                              } else {
                                _selected.remove(tag.id);
                              }
                            }),
                            visualDensity: VisualDensity.compact,
                          ),

                          // Color dot — tap to show mini picker
                          _ColorDot(
                            color: dotColor,
                            onColorSelected: (c) => ref
                                .read(tagRepositoryProvider)
                                .updateTagColor(tag.id, c?.toARGB32()),
                          ),
                          const SizedBox(width: 8),

                          // Tag name (inline edit or label)
                          Expanded(
                            child: isEditing
                                ? SizedBox(
                                    height: 28,
                                    child: TextField(
                                      controller: ctrl,
                                      autofocus: true,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: AppColors.textPrimary),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 4),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          borderSide: const BorderSide(
                                              color: AppColors.accent,
                                              width: 1),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          borderSide: const BorderSide(
                                              color: AppColors.accent,
                                              width: 1),
                                        ),
                                      ),
                                      onSubmitted: (v) async {
                                        final trimmed = v.trim();
                                        if (trimmed.isNotEmpty) {
                                          await ref
                                              .read(tagRepositoryProvider)
                                              .renameTag(tag.id, trimmed);
                                        }
                                        setState(() =>
                                            _editingId[tag.id] = false);
                                      },
                                    ),
                                  )
                                : Text(
                                    tag.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: AppColors.textPrimary),
                                  ),
                          ),

                          // Edit icon
                          IconButton(
                            icon: Icon(
                              isEditing ? Icons.check : Icons.edit_outlined,
                              size: 15,
                            ),
                            color: AppColors.textTertiary,
                            splashRadius: 14,
                            tooltip: isEditing ? 'Confirm' : 'Rename',
                            onPressed: () async {
                              if (isEditing) {
                                final trimmed = ctrl.text.trim();
                                if (trimmed.isNotEmpty) {
                                  await ref
                                      .read(tagRepositoryProvider)
                                      .renameTag(tag.id, trimmed);
                                }
                                setState(
                                    () => _editingId[tag.id] = false);
                              } else {
                                setState(
                                    () => _editingId[tag.id] = true);
                              }
                            },
                          ),

                          // Delete icon
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 15),
                            color: AppColors.textTertiary,
                            splashRadius: 14,
                            tooltip: 'Delete',
                            onPressed: () => _deleteTag(ctx, tag),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Merge button (appears when 2 tags are selected)
          if (_selected.length == 2)
            tagsAsync.whenData((tags) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.merge_type, size: 16),
                  label: const Text('Merge selected →'),
                  onPressed: () => _mergeTags(context, tags),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              );
            }).value ??
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// Small colored dot that opens an inline color picker overlay on tap.
class _ColorDot extends StatefulWidget {
  const _ColorDot({required this.color, required this.onColorSelected});
  final Color color;
  final ValueChanged<Color?> onColorSelected;

  @override
  State<_ColorDot> createState() => _ColorDotState();
}

class _ColorDotState extends State<_ColorDot> {
  OverlayEntry? _overlay;

  void _showPicker(BuildContext context) {
    _removeOverlay();
    final box = context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    _overlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _removeOverlay,
            ),
          ),
          Positioned(
            left: pos.dx,
            top: pos.dy + size.height + 4,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.cardBorder, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // "no color" option
                    GestureDetector(
                      onTap: () {
                        _removeOverlay();
                        widget.onColorSelected(null);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.divider,
                          border: Border.all(
                              color: AppColors.cardBorder, width: 0.5),
                        ),
                        child: const Icon(Icons.close,
                            size: 12, color: AppColors.textTertiary),
                      ),
                    ),
                    // Color swatches
                    for (final c in _kPalette)
                      GestureDetector(
                        onTap: () {
                          _removeOverlay();
                          widget.onColorSelected(c);
                        },
                        child: Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 3),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c,
                            border: widget.color == c
                                ? Border.all(
                                    color: AppColors.textPrimary, width: 2)
                                : Border.all(
                                    color: AppColors.cardBorder,
                                    width: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
        ),
      ),
    );
  }
}
