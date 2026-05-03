import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Creates a [QuillController] from stored body text.
///
/// The body may be:
/// - null / empty  → empty document
/// - Quill Delta JSON string → parsed directly
/// - plain text (legacy or pasted) → wrapped in a single-insert Delta
///
/// Pass [readOnly] true for display-only editors (notes feed view mode).
QuillController quillControllerFromBody(
  String? body, {
  bool readOnly = false,
}) {
  if (body == null || body.isEmpty) {
    return QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: readOnly,
    );
  }
  try {
    final ops = jsonDecode(body) as List;
    return QuillController(
      document: Document.fromJson(ops),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: readOnly,
    );
  } catch (_) {
    // Plain-text fallback: wrap in a minimal Delta so content is preserved.
    return QuillController(
      document: Document.fromJson([
        {'insert': '$body\n'}
      ]),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: readOnly,
    );
  }
}
