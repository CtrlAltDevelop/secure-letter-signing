import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/project_views_controller.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// The file types the Files tab can filter by (`type=` of the endpoint); empty is "all".
const projectFileTypes = ['', 'image', 'video', 'document'];

IconData fileTypeIcon(String contentType) {
  if (contentType.startsWith('image/')) return Icons.image_outlined;
  if (contentType.startsWith('video/')) return Icons.movie_outlined;
  return Icons.description_outlined;
}

/// Human size such as '۲ کیلوبایت'.
String formatFileSize(AppLocalizations l, int bytes) {
  if (bytes < 1024) return l.sizeBytes(toPersianDigits(bytes));
  if (bytes < 1024 * 1024) {
    return l.sizeKilobytes(toPersianDigits((bytes / 1024).round()));
  }
  return l.sizeMegabytes(
    toPersianDigits((bytes / (1024 * 1024)).toStringAsFixed(1)),
  );
}

/// Attachments of every task of the project, with a type filter and name search. When the
/// server has no files endpoint it shows an unavailable note instead of failing.
class ProjectFilesView extends StatefulWidget {
  const ProjectFilesView({
    super.key,
    required this.controller,
    required this.onDownload,
    required this.onOpenTask,
  });

  final ProjectFilesController controller;
  final ValueChanged<ProjectFile> onDownload;
  final ValueChanged<String> onOpenTask;

  @override
  State<ProjectFilesView> createState() => _ProjectFilesViewState();
}

class _ProjectFilesViewState extends State<ProjectFilesView> {
  final _search = TextEditingController();

  ProjectFilesController get _c => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _typeLabel(AppLocalizations l, String type) => switch (type) {
    'image' => l.fileTypeImage,
    'video' => l.fileTypeVideo,
    'document' => l.fileTypeDocument,
    _ => l.tasksFilterAll,
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _c,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      if (!_c.supported) {
        return EmptyState(
          icon: Icons.folder_off_outlined,
          title: l.projectFilesUnavailable,
        );
      }
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Tokens.gap,
          8,
          Tokens.gap,
          24,
        ),
        children: [
          TextField(
            key: const ValueKey('files-search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.filesSearchHint,
            ),
            onSubmitted: (v) => unawaited(_c.setQuery(v)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final t in projectFileTypes)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      key: ValueKey('file-type-$t'),
                      label: Text(_typeLabel(l, t)),
                      selected: _c.type == t,
                      onSelected: (_) => unawaited(_c.setType(t)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ..._rows(context),
        ],
      );
    },
  );

  List<Widget> _rows(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_c.loading && _c.files.isEmpty) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (_c.files.isEmpty) {
      return [EmptyState(icon: Icons.attach_file, title: l.filesEmpty)];
    }
    return [
      for (final f in _c.files)
        Card(
          key: ValueKey('file-${f.id}'),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(fileTypeIcon(f.contentType)),
            title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                formatFileSize(l, f.size),
                if (f.taskTitle.isNotEmpty) f.taskTitle,
                if (f.uploadedBy != null) f.uploadedBy!.displayName,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: f.taskId == null ? null : () => widget.onOpenTask(f.taskId!),
            trailing: IconButton(
              tooltip: l.fileDownload,
              icon: const Icon(Icons.download_outlined),
              onPressed: () => widget.onDownload(f),
            ),
          ),
        ),
    ];
  }
}
