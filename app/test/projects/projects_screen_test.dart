import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/l10n/app_localizations_fa.dart';
import 'package:letter_signing/projects/project_detail_screen.dart';
import 'package:letter_signing/projects/projects_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import 'project_fixtures.dart';

final _l = AppLocalizationsFa();
const _phone = Size(375, 812);
const _landscape = Size(844, 390);

Future<ProjectsFixture> _open(
  WidgetTester t, {
  Size size = _phone,
  bool canCreate = true,
  bool isManager = false,
  void Function(FakeProjectsServer s)? seed,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  final f = projectsFixture(canCreate: canCreate, isManager: isManager);
  seed?.call(f.server);
  await t.pumpWidget(faApp(ProjectsScreen(env: f.env)));
  await t.pumpAndSettle();
  return f;
}

void _grouped(FakeProjectsServer s) {
  s.projects
    ..clear()
    ..addAll([
      projectBrief('p1', name: 'Alpha', groupId: 1),
      projectBrief('p2', name: 'Beta', groupId: 1, status: 'done'),
      projectBrief('p3', name: 'Loose'),
    ]);
  s.groups.add({
    'id': 1,
    'name': 'Group One',
    'scope': 'org',
    'rank': 1,
    'active': true,
  });
}

void main() {
  for (final size in [_phone, _landscape]) {
    testWidgets('lists projects under their group at $size', (t) async {
      await _open(t, size: size, seed: _grouped);
      expect(find.text('Group One'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.byKey(const ValueKey('project-color-bar')), findsWidgets);
      expect(find.byKey(const ValueKey('member-count')), findsWidgets);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('a group can be collapsed', (t) async {
    await _open(t, seed: _grouped);
    await t.tap(find.byKey(const ValueKey('group-header-1')));
    await t.pumpAndSettle();
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Loose'), findsOneWidget);
  });

  testWidgets('status chip and search go to the server', (t) async {
    final f = await _open(t, seed: _grouped);
    expect(
      f.server.calls.any((r) => r.url.queryParameters['status'] == 'active'),
      isTrue,
    );
    await t.ensureVisible(find.byKey(const ValueKey('status-done')));
    await t.tap(find.byKey(const ValueKey('status-done')));
    await t.pumpAndSettle();
    expect(
      f.server.where('GET', '/projects').last.url.queryParameters['status'],
      'done',
    );
    await t.enterText(find.byKey(const ValueKey('projects-search')), 'alp');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(
      f.server.where('GET', '/projects').last.url.queryParameters['q'],
      'alp',
    );
  });

  testWidgets('create button only with project.create', (t) async {
    await _open(t, canCreate: false);
    expect(find.byKey(const ValueKey('project-create')), findsNothing);
    await _open(t);
    expect(find.byKey(const ValueKey('project-create')), findsOneWidget);
  });

  testWidgets('empty state', (t) async {
    await _open(t, seed: (s) => s.projects.clear());
    expect(find.text(_l.projectsEmptyTitle), findsOneWidget);
  });

  testWidgets('tapping a project opens its tabs', (t) async {
    final f = await _open(t);
    f.server.board = [boardTask('a', 1, 100, title: 'Task A')];
    await t.tap(find.text('Alpha'));
    await t.pumpAndSettle();
    expect(find.byType(ProjectDetailScreen), findsOneWidget);
    expect(find.text(_l.projectTabBoard), findsOneWidget);
    expect(find.text('Task A'), findsOneWidget);
  });

  testWidgets('group sheet creates, renames and deactivates a group', (
    t,
  ) async {
    final f = await _open(t, seed: _grouped, isManager: true);
    await t.tap(find.byKey(const ValueKey('groups-manage')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('group-new')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('scope-personal')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('prompt-field')), 'Mine');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('prompt-confirm')));
    await t.pumpAndSettle();
    final body = f.server.lastBody('POST', '/project-groups')! as Map;
    expect(body, {'name': 'Mine', 'scope': 'personal'});
    expect(find.text('Mine'), findsWidgets);

    await t.tap(find.byKey(const ValueKey('group-rename-1')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('prompt-field')), 'Renamed');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('prompt-confirm')));
    await t.pumpAndSettle();
    expect(f.server.lastBody('PATCH', '/project-groups/1'), {
      'name': 'Renamed',
    });

    await t.tap(find.byKey(const ValueKey('group-toggle-1')));
    await t.pumpAndSettle();
    expect(f.server.lastBody('PATCH', '/project-groups/1'), {'active': false});
  });

  testWidgets('non-managers cannot edit organisation groups', (t) async {
    await _open(t, seed: _grouped);
    await t.tap(find.byKey(const ValueKey('groups-manage')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('group-rename-1')), findsNothing);
  });
}
