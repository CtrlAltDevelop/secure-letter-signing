import 'package:letter_signing/finance/finance_api.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/tasks/tasks_env.dart' show SaveFile;
import 'package:letter_signing/utils/save_bytes.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/label_cache.dart';
import 'package:letter_signing/workspace/models.dart';

/// What the Finance screens need: the API, the live stream, the user and the platform hooks
/// (file picker, save) that tests replace.
class FinanceEnv {
  FinanceEnv({
    required this.api,
    required this.live,
    required this.userId,
    FilePickFn? pickFile,
    SaveFile? saveFile,
  }) : pickFile = pickFile ?? pickOneFile,
       saveFile = saveFile ?? saveBytes,
       _labels = LabelCache(api.workspace);

  final FinanceApi api;
  final LiveService live;
  final int userId;
  final FilePickFn pickFile;
  final SaveFile saveFile;
  final LabelCache _labels;

  Future<List<LabelInfo>> labels() => _labels.labels();
  void invalidateLabels() => _labels.invalidate();
}
