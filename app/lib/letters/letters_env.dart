import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/auth/biometrics.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_service.dart';
import 'package:letter_signing/letters/letters_api.dart';
import 'package:letter_signing/letters/letters_v2_api.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/notifications_screen.dart';
import 'package:letter_signing/letters/sign_approvals.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/utils/save_bytes.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Everything the letter screens need, built once by the integrator after login.
class LettersEnv {
  LettersEnv({
    required this.api,
    required this.live,
    required this.userId,
    this.biometrics = const LocalAuthBiometrics(),
    this.canCreate = true,
    this.isManager = false,
    this.canSecretariat = false,
    this.tasksResolver,
    this.deviceName = '',
    this.enrollBiometric,
    this._sessionId,
    FilePickFn? pickFile,
    SaveFile? saveFile,
  }) : pickFile = pickFile ?? pickOneFile,
       saveFile = saveFile ?? saveBytes,
       letters = LetterService(api: api, userId: userId),
       notifications = NotificationsController(api: api, live: live),
       approvals = SignApprovals(api: api, live: live, biometrics: biometrics),
       workspace = WorkspaceApi(api.client, httpClient: api.httpClient);

  final LettersApi api;
  final LiveService live;
  final int userId;
  final Biometrics biometrics;

  /// Enrols this session's fingerprint/face with the PIN; null when unsupported.
  final Future<bool> Function(String pin)? enrollBiometric;
  final bool canCreate;
  final bool isManager;

  /// The user holds `letter.secretariat` (register of incoming and outgoing letters).
  final bool canSecretariat;

  /// Gives the letter screens the Tasks module env (opening, creating and linking tasks).
  TasksEnv Function()? tasksResolver;
  final String deviceName;

  /// Platform hooks (file picker, save) that tests replace.
  final FilePickFn pickFile;
  final SaveFile saveFile;

  /// Subject-level calls (labels, files, comments) over the same client.
  final WorkspaceApi workspace;

  /// Letters v2 calls (search, referrals, paraphs, secretariat).
  late final LettersV2Api v2 = LettersV2Api(workspace);

  Future<List<LabelInfo>>? _labels;
  Future<List<UserRef>>? _directory;

  /// Active labels, fetched once; a failure is not cached.
  Future<List<LabelInfo>> labels() => _labels ??= workspace
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
      _directory ??= workspace.directory().catchError((Object _) {
        _directory = null;
        return <UserRef>[];
      });

  final LetterService letters;
  final NotificationsController notifications;

  /// Incoming "approve this signature" requests for this device.
  final SignApprovals approvals;
  final String? Function()? _sessionId;

  /// Login `session_id` when the integrator supplied it.
  String? get sessionId => _sessionId?.call();

  /// Stops the controllers fed by the live stream. The stream itself belongs to `WorkspaceEnv`.
  Future<void> dispose() async {
    notifications.dispose();
    approvals.dispose();
  }
}

/// Shows a failure as a SnackBar (server messages are user-readable).
void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
}

String letterStatusLabel(AppLocalizations l, String status) => switch (status) {
  'draft' => l.letterStatusDraft,
  'in_signing' => l.letterStatusInSigning,
  'published' => l.letterStatusPublished,
  'rejected' => l.letterStatusRejected,
  'cancelled' => l.letterStatusCancelled,
  _ => status,
};

Tone statusTone(String status) => switch (status) {
  'published' => Tone.ok,
  'rejected' => Tone.error,
  'in_signing' => Tone.warn,
  'draft' => Tone.info,
  _ => Tone.neutral,
};

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) => StatusPill(
    letterStatusLabel(AppLocalizations.of(context), status),
    tone: statusTone(status),
  );
}
