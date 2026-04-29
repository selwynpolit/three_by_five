import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/database/app_database.dart';
import '../../../providers/detail_providers.dart';

class AttachmentsSectionWidget extends ConsumerWidget {
  const AttachmentsSectionWidget({
    super.key,
    required this.taskId,
    required this.attachmentsAsync,
  });

  final String taskId;
  final AsyncValue<List<AppAttachment>> attachmentsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = attachmentsAsync.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ATTACHMENTS',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '${attachments.length}',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AppColors.accentMuted),
              ),
            ],
          ],
        ),
        if (attachments.isEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Drop an image or paste a URL in the note box below.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textDisabled,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: attachments.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: 8),
              itemBuilder: (ctx, i) => _AttachmentTile(
                attachment: attachments[i],
                onDelete: () => ref
                    .read(attachmentRepositoryProvider)
                    .delete(attachments[i].id),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Attachment tile ────────────────────────────────────────────────────────────

class _AttachmentTile extends StatefulWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.onDelete,
  });

  final AppAttachment attachment;
  final VoidCallback onDelete;

  @override
  State<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<_AttachmentTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          _tileContent(context),
          if (_hovered)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xCC000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      size: 10, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tileContent(BuildContext context) {
    return switch (widget.attachment.type) {
      'image' => _ImageTile(
          filePath: widget.attachment.filePath ?? ''),
      'link' => _LinkTile(attachment: widget.attachment),
      _ => _EmailClipTile(attachment: widget.attachment),
    };
  }
}

// ── Image tile ────────────────────────────────────────────────────────────────

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.filePath});
  final String filePath;

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 110,
        height: 90,
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : const ColoredBox(
                color: AppColors.divider,
                child: Icon(Icons.broken_image_outlined,
                    color: AppColors.textTertiary),
              ),
      ),
    );
  }
}

// ── Link tile ─────────────────────────────────────────────────────────────────

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.attachment});
  final AppAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final title = attachment.linkTitle ??
        Uri.tryParse(attachment.url ?? '')?.host ??
        'Link';
    final domain =
        Uri.tryParse(attachment.url ?? '')?.host ?? '';

    return Container(
      width: 160,
      height: 90,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.link,
                  size: 14, color: AppColors.accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  domain,
                  style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.accentMuted,
                          ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Email clip tile ────────────────────────────────────────────────────────────

class _EmailClipTile extends StatelessWidget {
  const _EmailClipTile({required this.attachment});
  final AppAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 90,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.email_outlined,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  attachment.emailSender ?? 'Email',
                  style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            attachment.emailSubject ?? '(no subject)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
