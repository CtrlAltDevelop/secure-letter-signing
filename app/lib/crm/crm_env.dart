import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/crm/crm_api.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/meetings/meetings_env.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/utils/save_bytes.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/label_cache.dart';
import 'package:letter_signing/workspace/models.dart';

/// Builds a panel of another module for one customer file, or null when that module is
/// disabled or the user lacks its permission.
typedef CustomerPanelBuilder = Widget? Function(String customerId);

/// What the CRM screens need: the API, the live stream, the user, the envs of the modules a
/// customer file links to, and the platform hooks (file picker, save) that tests replace.
class CrmEnv {
  CrmEnv({
    required this.api,
    required this.live,
    required this.userId,
    required this.tasks,
    required this.meetings,
    required this.letters,
    this.canCreate = true,
    this.canImport = false,
    this.financePanel,
    this.leadsPanel,
    this.chatTab,
    FilePickFn? pickFile,
    SaveFile? saveFile,
  }) : pickFile = pickFile ?? pickOneFile,
       saveFile = saveFile ?? saveBytes,
       _labels = LabelCache(api.workspace);

  final CrmApi api;
  final LiveService live;
  final int userId;
  final TasksEnv tasks;
  final MeetingsEnv meetings;
  final LettersEnv letters;

  /// `customer.create` / `customer.import`.
  final bool canCreate;
  final bool canImport;

  /// Finance, leads and chat panels (null result hides the tab).
  final CustomerPanelBuilder? financePanel;
  final CustomerPanelBuilder? leadsPanel;
  final CustomerPanelBuilder? chatTab;

  final FilePickFn pickFile;
  final SaveFile saveFile;
  final LabelCache _labels;
  Future<List<UserRef>>? _directory;

  Future<List<LabelInfo>> labels() => _labels.labels();
  void invalidateLabels() => _labels.invalidate();

  /// Colleagues for the members editor, fetched once.
  Future<List<UserRef>> directory() =>
      _directory ??= api.workspace.directory().catchError((Object _) {
        _directory = null;
        return <UserRef>[];
      });
}
