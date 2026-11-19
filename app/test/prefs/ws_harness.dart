import 'package:http/http.dart' as http;
import 'package:letter_signing/tasks/tasks_api.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

import '../letters/fakes.dart';

/// A [TasksEnv] (and its [WorkspaceApi]) over a scripted server; paths carry the `/api` prefix.
class Ws {
  Ws(this.tasks, this.calls);
  final TasksEnv tasks;
  final List<http.Request> calls;
  WorkspaceApi get api => tasks.api.workspace;

  Iterable<http.Request> where(String method, String part) =>
      calls.where((r) => r.method == method && r.url.toString().contains(part));
}

Ws ws(Handler handler) {
  final f = fakeApi(handler);
  final env = TasksEnv(
    api: TasksApi(f.client, httpClient: f.api.httpClient),
    live: FakeLive(f.client),
    userId: 2,
  );
  return Ws(env, f.calls);
}

/// The request path without the `/api` prefix.
String pathOf(http.Request r) => r.url.path.replaceFirst('/api', '');
