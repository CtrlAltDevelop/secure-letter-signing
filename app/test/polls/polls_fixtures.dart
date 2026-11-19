import 'package:http/http.dart' as http;
import 'package:letter_signing/polls/polls_api.dart';
import 'package:letter_signing/polls/polls_env.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

import '../letters/fakes.dart';

const targetSubject = 'subj-1';

/// A scripted in-memory polls server; every request and body is recorded.
class FakePollsServer {
  /// Whether the caller moderates (sees close, scores, voters).
  bool moderator = false;
  bool closed = false;
  bool submitted = false;
  Map<String, dynamic> poll = _poll();
  final List<Map<String, dynamic>> templates = [];
  final List<http.Request> calls = [];
  final List<Object?> bodies = [];
  List<Map<String, dynamic>> answers = [];

  static Map<String, dynamic> _poll({String kind = 'poll'}) => {
    'id': 'p1',
    'subject_id': 'ps-1',
    'target_subject_id': targetSubject,
    'title': 'Lunch',
    'kind': kind,
    'anonymity': 'public',
    'status': 'open',
    'participants': 0,
    'question_count': 1,
    'i_submitted': false,
    'creator': {'id': 9, 'full_name': 'Sara', 'email': 's@x.io'},
    'created_at': '2026-01-01T00:00:00Z',
    'questions': [
      {
        'id': 7,
        'text': 'Where?',
        'multiple': false,
        'points': 1,
        'options': [
          {'id': 70, 'text': 'Pizza'},
          {'id': 71, 'text': 'Kebab'},
        ],
        'correct_option_ids': null,
      },
    ],
  };

  Iterable<http.Request> where(String method, String part) =>
      calls.where((r) => r.method == method && r.url.path.contains(part));

  Object? lastBody(String method, String part) {
    for (var i = calls.length - 1; i >= 0; i--) {
      if (calls[i].method == method && calls[i].url.path.contains(part)) {
        return bodies[i];
      }
    }
    return null;
  }

  Map<String, dynamic> out() => {
    ...poll,
    'status': closed ? 'closed' : 'open',
    'participants': submitted ? 1 : 0,
    'i_submitted': submitted,
    'my_answers': {
      for (final a in answers) '${a['question_id']}': a['option_ids'],
    },
    'can': {
      'submit': !closed,
      'close': moderator && !closed,
      'results': moderator || closed || submitted,
      'see_voters': moderator,
    },
  };

  Map<String, dynamic> results() {
    int count(int id) => [
      for (final a in answers)
        if ((a['option_ids'] as List).contains(id)) 1,
    ].length;
    return {
      'poll_id': 'p1',
      'kind': poll['kind'],
      'status': closed ? 'closed' : 'open',
      'participants': submitted ? 1 : 0,
      'questions': [
        {
          'id': 7,
          'text': 'Where?',
          'multiple': false,
          'points': 1,
          'correct_option_ids': moderator ? [70] : null,
          'options': [
            for (final o in [
              {'id': 70, 'text': 'Pizza'},
              {'id': 71, 'text': 'Kebab'},
            ])
              {
                ...o,
                'count': count(o['id']! as int),
                'voters': moderator && count(o['id']! as int) > 0
                    ? [
                        {'id': 2, 'full_name': 'Ali', 'email': 'a@x.io'},
                      ]
                    : null,
              },
          ],
        },
      ],
      'scores': moderator && poll['kind'] == 'quiz'
          ? [
              {
                'user': {'id': 2, 'full_name': 'Ali', 'email': 'a@x.io'},
                'score': 1,
                'max_score': 1,
              },
            ]
          : null,
      'my_score': null,
      'max_score': poll['kind'] == 'quiz' ? 1 : null,
    };
  }

  http.Response handle(http.Request req, Object? body) {
    calls.add(req);
    bodies.add(body);
    final path = req.url.path.replaceFirst('/api', '');
    final m = req.method;
    if (path == '/polls' && m == 'GET') {
      return json([out()]);
    }
    if (path == '/polls' && m == 'POST') {
      poll = {..._poll(kind: (body as Map)['kind'] as String)};
      return json(out(), 201);
    }
    if (path == '/poll-templates' && m == 'GET') return json(templates);
    if (path == '/poll-templates' && m == 'POST') {
      final b = body! as Map;
      templates.add({
        'id': templates.length + 1,
        'name': b['name'],
        'scope': b['scope'],
        'data': b['data'],
        'active': true,
      });
      return json(templates.last, 201);
    }
    if (path.endsWith('/submit')) {
      answers = [
        for (final a in (body! as Map)['answers'] as List)
          Map<String, dynamic>.from(a as Map),
      ];
      submitted = true;
      return json(out());
    }
    if (path.endsWith('/close')) {
      closed = true;
      return json(out());
    }
    if (path.endsWith('/results')) return json(results());
    if (path == '/me/letterhead') return json(<String, dynamic>{});
    return json(out());
  }
}

PollsEnv pollsEnv(FakePollsServer server) {
  final f = fakeApi(server.handle);
  return PollsEnv(
    api: PollsApi(WorkspaceApi(f.client, httpClient: f.api.httpClient)),
    live: FakeLive(f.client),
    userId: 2,
  );
}
