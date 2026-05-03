import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../core/theme/app_colors.dart';

/// Renders locally-stored image embeds in Quill editors.
///
/// Image data is stored as a file-system path string in the Delta.
/// Used by both the note composer (edit mode) and the notes feed (read mode).
class QuillImageEmbedBuilder extends EmbedBuilder {
  const QuillImageEmbedBuilder();

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final path = embedContext.node.value.data as String;
    final file = File(path);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340, maxHeight: 260),
          child: file.existsSync()
              ? Image.file(file, fit: BoxFit.contain)
              : Container(
                  width: 160,
                  height: 80,
                  color: AppColors.divider,
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppColors.textTertiary),
                ),
        ),
      ),
    );
  }
}
