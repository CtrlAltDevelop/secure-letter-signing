import 'package:letter_signing/bookmarks/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Typed access to `/bookmarks` and `/pins`. Errors 403/404/409 are typed exceptions.
class BookmarksApi {
  BookmarksApi(this.workspace);

  final WorkspaceApi workspace;

  Future<List<Bookmark>> list({String? module}) async {
    final q = WorkspaceApi.query({'module': module});
    final data = await workspace.call('GET', '/bookmarks$q');
    return [for (final j in asMapList(data)) Bookmark.fromJson(j)];
  }

  /// Idempotent. [id] is the subject id or the module object id (chat: the message id).
  Future<Bookmark> add(String module, String id, {String? note}) async =>
      Bookmark.fromJson(
        asMap(
          await workspace.call(
            'PUT',
            '/bookmarks',
            body: {'module': module, 'id': id, 'note': ?note},
          ),
        ),
      );

  Future<void> remove(int bookmarkId) =>
      workspace.call('DELETE', '/bookmarks/$bookmarkId');

  Future<List<Pin>> pins() async => [
    for (final j in asMapList(await workspace.call('GET', '/pins')))
      Pin.fromJson(j),
  ];

  Future<List<Pin>> pin(String subjectId) async => [
    for (final j in asMapList(
      await workspace.call('PUT', '/pins', body: {'subject_id': subjectId}),
    ))
      Pin.fromJson(j),
  ];

  Future<void> unpin(String subjectId) =>
      workspace.call('DELETE', '/pins/$subjectId');
}
