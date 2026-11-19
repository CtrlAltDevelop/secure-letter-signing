import 'package:letter_signing/notes/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Typed access to `/notes`. Images, labels and comments use the subject endpoints on
/// [workspace]. Errors 403/404/409 are typed exceptions.
class NotesApi {
  NotesApi(this.workspace);

  final WorkspaceApi workspace;

  Future<NoteOut> _note(String method, String path, {Object? body}) async =>
      NoteOut.fromJson(asMap(await workspace.call(method, path, body: body)));

  Future<List<NoteOut>> list(
    NoteFilter filter, {
    int limit = 100,
    int offset = 0,
  }) async {
    final q = WorkspaceApi.query(filter.toQuery(limit: limit, offset: offset));
    final data = await workspace.call('GET', '/notes$q');
    return [for (final j in asMapList(data)) NoteOut.fromJson(j)];
  }

  Future<NoteOut> get(String id) => _note('GET', '/notes/$id');

  Future<NoteOut> create({
    String title = '',
    String body = '',
    int color = 0,
    bool pinned = false,
    List<String> checklist = const [],
  }) => _note(
    'POST',
    '/notes',
    body: {
      'title': title,
      'body': {'text': body},
      'color': color,
      'pinned': pinned,
      'checklist': checklist,
    },
  );

  Future<NoteOut> patch(String id, {String? title, String? body, int? color}) =>
      _note(
        'PATCH',
        '/notes/$id',
        body: {
          'title': ?title,
          if (body != null) 'body': {'text': body},
          'color': ?color,
        },
      );

  Future<NoteOut> addItem(String id, String text) =>
      _note('POST', '/notes/$id/checklist', body: {'text': text});

  Future<NoteOut> patchItem(
    String id,
    int itemId, {
    String? text,
    bool? done,
    bool? active,
  }) => _note(
    'PATCH',
    '/notes/$id/checklist/$itemId',
    body: {'text': ?text, 'done': ?done, 'active': ?active},
  );

  Future<NoteOut> reorder(String id, List<int> itemIds) =>
      _note('PUT', '/notes/$id/checklist/order', body: {'item_ids': itemIds});

  Future<NoteOut> pin(String id, {required bool pinned}) =>
      _note('POST', '/notes/$id/pin', body: {'pinned': pinned});

  Future<NoteOut> archive(String id, {required bool archived}) =>
      _note('POST', '/notes/$id/archive', body: {'archived': archived});
}
