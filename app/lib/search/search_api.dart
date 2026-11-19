import 'package:letter_signing/api/api_client.dart' show ApiException;
import 'package:letter_signing/search/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// The server refuses to search more than 60 times a minute (429).
class SearchRateLimited implements Exception {
  const SearchRateLimited();
}

/// Typed access to `GET /search`.
class SearchApi {
  SearchApi(this.workspace);

  final WorkspaceApi workspace;

  /// [q] needs at least [minQuery] characters; [modules] narrows to some module codes.
  Future<List<SearchHit>> search(
    String q, {
    List<String> modules = const [],
    int limit = 20,
  }) async {
    final query = WorkspaceApi.query({
      'q': q,
      'modules': modules.join(','),
      'limit': limit,
    });
    try {
      final data = await workspace.call('GET', '/search$query');
      return [for (final j in asMapList(data)) SearchHit.fromJson(j)];
    } on ApiException catch (e) {
      if (e.status == 429) throw const SearchRateLimited();
      rethrow;
    }
  }

  static const minQuery = 2;
}
