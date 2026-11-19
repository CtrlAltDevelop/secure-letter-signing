import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Active labels, fetched once; a failure is not cached.
class LabelCache {
  LabelCache(this.api);
  final WorkspaceApi api;
  Future<List<LabelInfo>>? _labels;

  Future<List<LabelInfo>> labels() => _labels ??= api
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

  void invalidate() => _labels = null;
}
