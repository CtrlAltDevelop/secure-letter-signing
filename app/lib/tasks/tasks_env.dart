import 'dart:typed_data';

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/projects/projects_api.dart';
import 'package:letter_signing/tasks/tasks_api.dart';
import 'package:letter_signing/utils/save_bytes.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/models.dart';

typedef SaveFile = Future<void> Function(
  Uint8List bytes, {
  required String name,
  String? mimeType,
});

/// What the Tasks screens need: the API, the shared live stream, the signed-in user and the
/// platform hooks (file picker, save) that tests replace.
class TasksEnv {
  TasksEnv({
    required this.api,
    required this.live,
    required this.userId,
    this.canCreate = true,
    this.userName = '',
    FilePickFn? pickFile,
    SaveFile? saveFile,
    this.pickCustomer,
  }) : pickFile = pickFile ?? pickOneFile,
       saveFile = saveFile ?? saveBytes;

  final TasksApi api;
  final LiveService live;
  final int userId;
  final bool canCreate;

  /// Display name of the signed-in user, to label them in pickers before the directory loads.
  final String userName;
  final FilePickFn pickFile;
  final SaveFile saveFile;

  /// Customer-file picker (id and name); null hides the customer filter.
  final Future<({String id, String name})?> Function(BuildContext context)?
  pickCustomer;

  /// Project calls (pickers, move/copy) over the same client.
  late final ProjectsApi projects = ProjectsApi(api.workspace);

  Future<List<LabelInfo>>? _labels;
  Future<List<UserRef>>? _directory;

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

  /// Forgets the cached labels (after the labels screen changed them).
  void invalidateLabels() => _labels = null;

  /// Colleagues for the people pickers, fetched once.
  Future<List<UserRef>> directory() =>
      _directory ??= api.workspace.directory().catchError((Object _) {
        _directory = null;
        return <UserRef>[];
      });
}
