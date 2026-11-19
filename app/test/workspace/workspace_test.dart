import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/brand.dart';
import 'package:letter_signing/meetings/meetings_screen.dart';
import 'package:letter_signing/projects/projects_screen.dart';
import 'package:letter_signing/tasks/tasks_screen.dart';
import 'package:letter_signing/workspace/module_registry.dart';
import 'package:letter_signing/workspace/workspace_env.dart';

import '../helpers.dart';
import '../letters/fakes.dart';

const _user = UserInfo(
  id: 2,
  email: 'a@x.test',
  fullName: 'A',
  title: '',
  department: '',
  isManager: false,
  permissions: ['letter.see'],
);

WorkspaceEnv env(Handler h) {
  final f = fakeApi(h);
  final live = FakeLive(f.client);
  return WorkspaceEnv(
    api: f.client,
    live: live,
    user: _user,
    letters: testEnv(f, live: live),
  );
}

void main() {
  test('loadModules keeps only enabled known modules', () async {
    final e = env(
      (req, _) => req.url.path == '/api/me/modules'
          ? json({
              'plan': 'pro',
              'modules': [
                {'code': 'letters', 'enabled': true},
                {'code': 'tasks', 'enabled': false},
                {'code': 'projects', 'enabled': true},
              ],
            })
          : json({}),
    );
    await e.loadModules();
    expect(e.plan, 'pro');
    expect(enabledModules(e).map((m) => m.code), ['projects', 'letters']);
  });

  test('a 404 falls back to all modules enabled', () async {
    final e = env((_, _) => json({'detail': 'nope'}, 404));
    await e.loadModules();
    // Finance and sales also need their permission, which this user lacks.
    expect(enabledModules(e).map((m) => m.code), [
      for (final m in appModules)
        if (m.permission == null) m.code,
    ]);
  });

  test('a network error falls back to all modules enabled', () async {
    final e = env((_, _) => throw const FormatException('offline'));
    await e.loadModules();
    expect(e.enabledModules, containsAll(knownModuleCodes));
  });

  test('a malformed body keeps the default', () async {
    final e = env((_, _) => json([1]));
    await e.loadModules();
    expect(e.enabledModules, containsAll(knownModuleCodes));
  });

  test('registry order starts with tasks, projects, letters, meetings', () {
    expect(appModules.map((m) => m.code).take(4), [
      'tasks',
      'projects',
      'letters',
      'meetings',
    ]);
    expect(appModules.map((m) => m.code), containsAll(['finance', 'sales']));
  });

  test('finance and sales need their permission as well as the module', () {
    final e = env((_, _) => json({'detail': 'nope'}, 404));
    final codes = enabledModules(e).map((m) => m.code);
    expect(codes, isNot(contains('finance')));
    expect(codes, isNot(contains('sales')));
    final finance = appModules.firstWhere((m) => m.code == 'finance');
    expect(finance.permission, 'finance.manage');
  });

  testWidgets('the meetings module builds the real Meetings screen', (t) async {
    final e = env((_, _) => json([]));
    final meetings = appModules.firstWhere((m) => m.code == 'meetings');
    await t.pumpWidget(faApp(meetings.build(e)));
    await t.pumpAndSettle();
    expect(find.byType(MeetingsScreen), findsOneWidget);
    expect(find.text('جلسه‌ای وجود ندارد'), findsOneWidget);
  });

  testWidgets('the projects module builds the real Projects screen', (t) async {
    final e = env((_, _) => json([]));
    final projects = appModules.firstWhere((m) => m.code == 'projects');
    await t.pumpWidget(faApp(projects.build(e)));
    await t.pumpAndSettle();
    expect(find.byType(ProjectsScreen), findsOneWidget);
    expect(find.text('به‌زودی'), findsNothing);
  });

  testWidgets('the tasks module builds the real Tasks screen', (t) async {
    final e = env((_, _) => json([]));
    final tasks = appModules.firstWhere((m) => m.code == 'tasks');
    await t.pumpWidget(faApp(tasks.build(e)));
    await t.pumpAndSettle();
    expect(find.byType(TasksScreen), findsOneWidget);
    expect(find.text('به‌زودی'), findsNothing);
  });

  test('empty apiUrl resolves to the origin on web only', () {
    final brand = Brand.fromJson(
      '{"id":"d","name":"D","apiUrl":"",'
      '"colors":{"primary":"#000000","accent":"#000000","dark":"#000000"}}',
    );
    final base = Uri.parse('https://corp.test:8443/app/');
    expect(
      brand.resolvedApiUrl(web: true, base: base),
      'https://corp.test:8443',
    );
    expect(brand.resolvedApiUrl(web: false, base: base), '');
  });
}
