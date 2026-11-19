import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';

/// Files attached to a subject with upload, download and deactivate actions.
class FileList extends StatelessWidget {
  const FileList({
    super.key,
    required this.files,
    required this.currentUserId,
    required this.onUpload,
    required this.onDownload,
    required this.onDeactivate,
    this.canUpload = true,
  });

  /// Null while loading.
  final List<FileInfo>? files;
  final int currentUserId;
  final bool canUpload;
  final Future<void> Function() onUpload;
  final Future<void> Function(FileInfo file) onDownload;
  final Future<void> Function(FileInfo file) onDeactivate;

  /// '12 KB', '3.4 MB' with Persian digits.
  static String formatSize(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes < kb) return '${toPersianDigits(bytes)} B';
    if (bytes < mb) return '${toPersianDigits((bytes / kb).round())} KB';
    return '${toPersianDigits((bytes / mb).toStringAsFixed(1))} MB';
  }

  IconData _icon(String type) {
    if (type.startsWith('image/')) return Icons.image_outlined;
    if (type == 'application/pdf') return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = files;
    if (rows == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rows.isEmpty)
          EmptyState(icon: Icons.attach_file, title: l.filesEmpty),
        for (final f in rows) _row(context, l, f),
        if (canUpload)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => unawaited(onUpload()),
              icon: const Icon(Icons.upload_file),
              label: Text(l.fileUpload),
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, AppLocalizations l, FileInfo f) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final who = f.uploadedBy?.displayName;
    final when = f.createdAt == null ? null : formatRelative(f.createdAt!);
    return Padding(
      key: ValueKey('file-${f.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(_icon(f.contentType), color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(
                    [formatSize(f.size), ?who, ?when].join(' · '),
                    style: muted,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l.fileDownload,
              icon: const Icon(Icons.download_outlined),
              onPressed: () => unawaited(onDownload(f)),
            ),
            if (f.uploadedBy?.id == currentUserId)
              IconButton(
                tooltip: l.fileDelete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => unawaited(onDeactivate(f)),
              ),
          ],
        ),
      ),
    );
  }
}
