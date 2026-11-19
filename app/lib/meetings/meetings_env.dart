import 'package:letter_signing/auth/biometrics.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/meetings/meetings_api.dart';
import 'package:letter_signing/projects/projects_api.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/utils/save_bytes.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/models.dart';

/// What the Meetings screens need: the API, the shared live stream, the signed-in user, the
/// Tasks env (to open follow-up tasks) and the platform hooks that tests replace.
class MeetingsEnv {
  MeetingsEnv({
    required this.api,
    required this.live,
    required this.userId,
    required this.tasks,
    this.userName = '',
    this.isManager = false,
    this.biometrics = const LocalAuthBiometrics(),
    FilePickFn? pickFile,
    SaveFile? saveFile,
  }) : pickFile = pickFile ?? pickOneFile,
       saveFile = saveFile ?? saveBytes;

  final MeetingsApi api;
  final LiveService live;
  final int userId;
  final TasksEnv tasks;
  final String userName;

  /// The manager may create organisation-wide templates.
  final bool isManager;
  final Biometrics biometrics;
  final FilePickFn pickFile;
  final SaveFile saveFile;

  /// Project calls (the project picker of the form) over the same client.
  ProjectsApi get projects => tasks.projects;

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

  /// Colleagues for the people pickers, fetched once.
  Future<List<UserRef>> directory() =>
      _directory ??= api.workspace.directory().catchError((Object _) {
        _directory = null;
        return <UserRef>[];
      });
}
