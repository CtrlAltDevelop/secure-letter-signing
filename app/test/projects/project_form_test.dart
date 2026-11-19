import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/l10n/app_localizations_fa.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/project_form_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import 'project_fixtures.dart';

final _l = AppLocalizationsFa();

Future<({ProjectsFixture f, List<ProjectOut> result})> _open(
  WidgetTester t, {
  bool edit = false,
  Size size = const Size(375, 812),
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  final f = projectsFixture();
  final project = edit ? ProjectOut.fromJson(f.server.detail('p1')) : null;
  final result = <ProjectOut>[];
  await t.pumpWidget(
    faApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final r = await Navigator.of(context).push<ProjectOut>(
              MaterialPageRoute(
                builder: (_) => ProjectFormScreen(env: f.env, project: project),
              ),
            );
            if (r != null) result.add(r);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return (f: f, result: result);
}

Finder get _save => find.byKey(const ValueKey('project-save'));

void main() {
  testWidgets('an empty name shows the error and posts nothing', (t) async {
    final h = await _open(t);
    await t.tap(_save);
    await t.pumpAndSettle();
    expect(find.text(_l.projectNameRequired), findsOneWidget);
    expect(h.f.server.where('POST', '/projects'), isEmpty);
  });

  testWidgets('creating sends the name, colour and me as manager', (t) async {
    final h = await _open(t);
    await t.enterText(find.byKey(const ValueKey('project-name')), 'Launch');
    await t.tap(find.byKey(const ValueKey('color-3')));
    await t.pump();
    await t.tap(_save);
    await t.pumpAndSettle();
    final body = h.f.server.lastBody('POST', '/projects')! as Map;
    expect(body['name'], 'Launch');
    expect(body['color'], 3);
    expect(body['members'], [
      {'user_id': 2, 'role': 'manager'},
    ]);
    expect(h.result.single.name, 'Launch');
  });

  testWidgets('the owner row cannot change role', (t) async {
    await _open(t);
    final owner = t.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('role-2')),
    );
    expect(owner.onChanged, isNull);
  });

  testWidgets('editing saves changed fields and the member list', (t) async {
    final h = await _open(t, edit: true);
    await t.enterText(find.byKey(const ValueKey('project-name')), 'Alpha 2');
    await t.tap(find.byKey(const ValueKey('role-3')));
    await t.pumpAndSettle();
    await t.tap(find.text(_l.roleViewer).last);
    await t.pumpAndSettle();
    await t.tap(_save);
    await t.pumpAndSettle();
    expect(h.f.server.lastBody('PATCH', '/projects/p1'), {'name': 'Alpha 2'});
    expect(h.f.server.lastBody('PUT', '/projects/p1/members'), [
      {'user_id': 2, 'role': 'manager'},
      {'user_id': 3, 'role': 'viewer'},
    ]);
  });
}
