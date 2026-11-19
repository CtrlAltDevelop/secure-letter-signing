import 'package:letter_signing/polls/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Typed access to `/polls` and `/poll-templates`. Errors 403/404/409 are typed exceptions.
class PollsApi {
  PollsApi(this.workspace);
  final WorkspaceApi workspace;

  Future<List<Poll>> list({String? targetSubject, bool mine = false}) async {
    final q = WorkspaceApi.query({
      'target_subject': targetSubject,
      if (mine) 'mine': 'true',
    });
    return [
      for (final j in asMapList(await workspace.call('GET', '/polls$q')))
        Poll.fromJson(j),
    ];
  }

  Future<Poll> _poll(String method, String path, {Object? body}) async =>
      Poll.fromJson(asMap(await workspace.call(method, path, body: body)));

  Future<Poll> get(String id) => _poll('GET', '/polls/$id');

  Future<Poll> create({
    required String targetSubjectId,
    required String title,
    required String kind,
    required String anonymity,
    required List<QuestionDraft> questions,
  }) => _poll(
    'POST',
    '/polls',
    body: {
      'target_subject_id': targetSubjectId,
      'title': title.trim(),
      'kind': kind,
      'anonymity': anonymity,
      'questions': [for (final q in questions) q.toJson()],
    },
  );

  /// [answers]: question id -> chosen option ids (replaces the previous answers).
  Future<Poll> submit(String id, Map<int, Set<int>> answers) => _poll(
    'POST',
    '/polls/$id/submit',
    body: {
      'answers': [
        for (final e in answers.entries)
          {'question_id': e.key, 'option_ids': e.value.toList()..sort()},
      ],
    },
  );

  Future<Poll> close(String id) => _poll('POST', '/polls/$id/close');

  Future<PollResults> results(String id) async => PollResults.fromJson(
    asMap(await workspace.call('GET', '/polls/$id/results')),
  );

  Future<List<PollTemplate>> templates() async => [
    for (final j in asMapList(await workspace.call('GET', '/poll-templates')))
      PollTemplate.fromJson(j),
  ];

  Future<void> saveTemplate({
    required String name,
    required String title,
    required String kind,
    required String anonymity,
    required List<QuestionDraft> questions,
  }) => workspace.call(
    'POST',
    '/poll-templates',
    body: {
      'name': name.trim(),
      'scope': 'personal',
      'data': {
        'title': title.trim(),
        'kind': kind,
        'anonymity': anonymity,
        'questions': [for (final q in questions) q.toJson()],
      },
    },
  );
}
