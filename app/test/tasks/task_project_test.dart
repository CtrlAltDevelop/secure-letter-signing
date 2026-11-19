import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/l10n/app_localizations_fa.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/task_detail_screen.dart';
import 'package:letter_signing/tasks/task_form_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../projects/project_fixtures.dart';
import 'task_fixtures.dart';

final _l = AppLocalizationsFa();

Future<ProjectsFixture> _detail(
  WidgetTester t, {
  Size size = const Size(375, 812),
  void Function(Map<String, dynamic> task)? seed,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  final f = projectsFixture();
  final task = fullTask('t1', title: 'Moveable');
  seed?.call(task);
  f.server.tasks.tasks.add(task);
  await t.pumpWidget(faApp(TaskDetailScreen(env: f.env.tasks, taskId: 't1')));
  await t.pumpAndSettle();
  return f;
}

Future<void> _pickProject(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('target-project')));
  await t.pumpAndSettle();
  await t.tap(find.text('Alpha').last);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('shows project and column of a project task', (t) async {
    await _detail(
      t,
      seed: (task) {
        task['project_id'] = 'p1';
        task['column_id'] = 2;
      },
    );
    final text = t.widget<Text>(find.byKey(const ValueKey('task-project')));
    expect(text.data, contains('Alpha'));
    expect(text.data, contains('Doing'));
  });

  testWidgets('a personal task says so', (t) async {
    await _detail(t);
    expect(find.text(_l.taskNoProject), findsOneWidget);
  });

  testWidgets('move posts project and column and refreshes the task', (
    t,
  ) async {
    final f = await _detail(t);
    await t.ensureVisible(find.byKey(const ValueKey('task-move')));
    await t.tap(find.byKey(const ValueKey('task-move')));
    await t.pumpAndSettle();
    await _pickProject(t);
    await t.tap(find.byKey(const ValueKey('target-confirm')));
    await t.pumpAndSettle();
    expect(f.server.lastBody('POST', '/tasks/t1/move'), {
      'project_id': 'p1',
      'column_id': 1,
      'before_id': null,
    });
  });

  testWidgets('copy posts the target project and confirms', (t) async {
    final f = await _detail(t);
    await t.ensureVisible(find.byKey(const ValueKey('task-copy')));
    await t.tap(find.byKey(const ValueKey('task-copy')));
    await t.pumpAndSettle();
    await _pickProject(t);
    await t.tap(find.byKey(const ValueKey('target-confirm')));
    await t.pumpAndSettle();
    expect(f.server.lastBody('POST', '/tasks/t1/copy'), {'project_id': 'p1'});
    expect(find.text(_l.taskCopied), findsOneWidget);
  });

  testWidgets('move needs the move right', (t) async {
    await _detail(
      t,
      seed: (task) => task['can'] = {...canJson(comment: true), 'move': false},
    );
    expect(find.byKey(const ValueKey('task-move')), findsNothing);
    expect(find.byKey(const ValueKey('task-copy')), findsOneWidget);
  });

  testWidgets('detail has a reminders card', (t) async {
    await _detail(t, size: const Size(844, 390));
    await t.scrollUntilVisible(
      find.text(_l.remindersTitle),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(_l.remindersTitle), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  group('task form', () {
    Future<ProjectsFixture> form(
      WidgetTester t, {
      bool inProject = false,
    }) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(800, 2400);
      addTearDown(t.view.reset);
      final f = projectsFixture();
      await t.pumpWidget(
        faApp(
          TaskFormScreen(
            env: f.env.tasks,
            initialProjectId: inProject ? 'p1' : null,
            initialColumnId: inProject ? 2 : null,
          ),
        ),
      );
      await t.pumpAndSettle();
      return f;
    }

    testWidgets('a task created from a project passes project and column', (
      t,
    ) async {
      final f = await form(t, inProject: true);
      expect(find.byKey(const ValueKey('target-project')), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('form-title')), 'In project');
      await t.pump();
      await t.tap(find.widgetWithText(TextButton, _l.commonSave));
      await t.pumpAndSettle();
      final body = f.server.tasks.lastBody('POST', '/tasks')! as Map;
      expect(body['project_id'], 'p1');
      expect(body['column_id'], 2);
      expect(body['owner_ids'], [2]);
    });

    testWidgets('members can pick a project in the form', (t) async {
      final f = await form(t);
      await _pickProject(t);
      await t.enterText(find.byKey(const ValueKey('form-title')), 'Picked');
      await t.pump();
      await t.tap(find.widgetWithText(TextButton, _l.commonSave));
      await t.pumpAndSettle();
      final body = f.server.tasks.lastBody('POST', '/tasks')! as Map;
      expect(body['project_id'], 'p1');
      expect(body['column_id'], 1);
    });

    testWidgets('a label can be created inline and is selected', (t) async {
      final f = await form(t);
      await t.tap(find.byKey(const ValueKey('label-new')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('label-name')), 'Fresh');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('label-save')));
      await t.pumpAndSettle();
      expect(f.server.lastBody('POST', '/labels'), {
        'name': 'Fresh',
        'color': 0,
        'scope': 'personal',
      });
      await t.enterText(find.byKey(const ValueKey('form-title')), 'Labelled');
      await t.pump();
      await t.tap(find.widgetWithText(TextButton, _l.commonSave));
      await t.pumpAndSettle();
      final body = f.server.tasks.lastBody('POST', '/tasks')! as Map;
      expect(body['label_ids'], [1]);
    });

    testWidgets('the project field is hidden without projects', (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(800, 2400);
      addTearDown(t.view.reset);
      final f = projectsFixture();
      f.server.projects.clear();
      await t.pumpWidget(faApp(TaskFormScreen(env: f.env.tasks)));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('target-project')), findsNothing);
    });
  });

  test('TaskBrief reads column and rank, draft sends them', () {
    final b = TaskBrief.fromJson({
      ...briefTask('x'),
      'column_id': 4,
      'rank': 65536,
    });
    expect(b.columnId, 4);
    expect(b.rank, 65536);
    const d = TaskDraft(title: 't', projectId: 'p', columnId: 4);
    expect(d.toCreateJson()['column_id'], 4);
    expect(const TaskDraft(title: 't').toCreateJson()['project_id'], isNull);
  });
}
