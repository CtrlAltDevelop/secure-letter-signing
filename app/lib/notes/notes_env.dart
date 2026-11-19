import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/notes/notes_api.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/models.dart';

/// What the Notes screens need: the API, the shared live stream and the platform file picker
/// (replaced by tests).
class NotesEnv {
  NotesEnv({
    required this.api,
    required this.live,
    required this.userId,
    FilePickFn? pickFile,
  }) : pickFile = pickFile ?? pickOneFile;

  final NotesApi api;
  final LiveService live;
  final int userId;
  final FilePickFn pickFile;

  Future<List<LabelInfo>>? _labels;

  /// Active labels, fetched once; a failure is not cached.
  Future<List<LabelInfo>> labels() => _labels ??= api.workspace
      .labels()
      .then(
        (all) => [
          for (final l in all)
            if (l.active) l,
        ],
      )
      .catchError((Object _) {
        _labels = null;
        return <LabelInfo>[];
      });

  /// Forgets the cached labels (after a label was created).
  void invalidateLabels() => _labels = null;
}
