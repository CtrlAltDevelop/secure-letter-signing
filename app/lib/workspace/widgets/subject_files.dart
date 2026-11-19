import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letters_env.dart' show showError;
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/tasks/tasks_env.dart' show SaveFile;
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/subject_controller.dart';
import 'package:letter_signing/workspace/widgets/file_list.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// The generic subject files (`/subjects/{id}/files`) as a self-contained section: loads,
/// uploads, downloads and deactivates, and reloads on live `file.*` events.
class SubjectFiles extends StatefulWidget {
  const SubjectFiles({
    super.key,
    required this.api,
    required this.live,
    required this.subjectId,
    required this.userId,
    required this.pickFile,
    required this.saveFile,
    this.onChanged,
  });

  final WorkspaceApi api;
  final LiveService live;
  final String subjectId;
  final int userId;
  final FilePickFn pickFile;
  final SaveFile saveFile;

  /// Called with the file count after every reload.
  final ValueChanged<int>? onChanged;

  @override
  State<SubjectFiles> createState() => _SubjectFilesState();
}

class _SubjectFilesState extends State<SubjectFiles> {
  late final SubjectController _c = SubjectController(
    api: widget.api,
    live: widget.live,
    subjectId: widget.subjectId,
  )..addListener(_changed);

  @override
  void initState() {
    super.initState();
    unawaited(_c.loadFiles());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _changed() => widget.onChanged?.call(_c.files?.length ?? 0);

  Future<void> _upload() async {
    final picked = await widget.pickFile();
    if (picked == null || !mounted) return;
    final out = await _c.uploadFile(
      name: picked.name,
      bytes: picked.bytes,
      contentType: picked.contentType,
    );
    if (out != ActionOutcome.ok && mounted) showError(context, _c.lastError!);
  }

  Future<void> _download(FileInfo f) async {
    final bytes = await _c.download(f);
    if (!mounted) return;
    if (bytes == null) {
      showError(context, _c.lastError!);
      return;
    }
    await widget.saveFile(bytes, name: f.name, mimeType: f.contentType);
  }

  Future<void> _deactivate(FileInfo f) async {
    final out = await _c.deactivateFile(f.id);
    if (out != ActionOutcome.ok && mounted) showError(context, _c.lastError!);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _c,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).moneyFiles,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        FileList(
          files: _c.files,
          currentUserId: widget.userId,
          onUpload: _upload,
          onDownload: _download,
          onDeactivate: _deactivate,
        ),
      ],
    ),
  );
}
