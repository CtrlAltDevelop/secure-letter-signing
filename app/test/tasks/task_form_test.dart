import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations_fa.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/task_form_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import 'task_fixtures.dart';

final _l = AppLocalizationsFa();

/// Opens the form from a button so the popped result can be read.
class _Harness {
  TaskOut? result;
  bool popped = false;
}

Future<_Harness> _open(
  WidgetTester t,
  TasksFixture f, {
  TaskOut? task,
  Size size = const Size(800, 2400),
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  final h = _Harness();
  await t.pumpWidget(
    faApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            h.result = await Navigator.of(context).push<TaskOut>(
              MaterialPageRoute(
                builder: (_) => TaskFormScreen(env: f.env, task: task),
              ),
            );
            h.popped = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return h;
}

Finder get _titleField => find.byKey(const ValueKey('form-title'));
Finder get _save => find.widgetWithText(TextButton, _l.commonSave);

void main() {
  testWidgets('saving with an empty title shows the error and posts nothing', (
    t,
  ) async {
    final f = tasksFixture();
    await _open(t, f);
    await t.tap(_save);
    await t.pumpAndSettle();
    expect(find.text(_l.formTitleRequired), findsOneWidget);
    expect(f.server.where('POST', '/tasks'), isEmpty);
  });

  testWidgets('owners default to me', (t) async {
    final f = tasksFixture();
    await _open(t, f);
    expect(
      find.descendant(of: find.byType(InputChip), matching: find.text('Me')),
      findsOneWidget,
    );
    await t.enterText(_titleField, 'Write minutes');
    await t.tap(_save);
    await t.pumpAndSettle();
    final body = f.server.lastBody('POST', '/tasks')! as Map;
    expect(body['owner_ids'], [2]);
    expect(body['title'], 'Write minutes');
    expect(body['priority'], 'normal');
  });

  testWidgets('removing the last owner blocks saving', (t) async {
    final f = tasksFixture();
    await _open(t, f);
    await t.enterText(_titleField, 'Orphan');
    await t.tap(find.byTooltip(_l.peopleRemove('Me')));
    await t.pump();
    await t.tap(_save);
    await t.pumpAndSettle();
    expect(find.text(_l.formOwnerRequired), findsOneWidget);
    expect(f.server.where('POST', '/tasks'), isEmpty);
  });

  testWidgets('picking people from the directory adds them in order', (
    t,
  ) async {
    final f = tasksFixture();
    await _open(t, f);
    await t.enterText(_titleField, 'Review');
    // The approvers picker is the second "add" chip.
    await t.tap(find.widgetWithText(ActionChip, _l.peopleAdd).at(1));
    await t.pumpAndSettle();
    await t.tap(find.text('Carol'));
    await t.tap(find.text('Bob'));
    await t.tap(find.text(_l.commonConfirm));
    await t.pumpAndSettle();
    await t.tap(_save);
    await t.pumpAndSettle();
    final body = f.server.lastBody('POST', '/tasks')! as Map;
    expect(body['approver_ids'], [4, 3]);
    expect(body['owner_ids'], [2]);
  });

  testWidgets('people search narrows the directory list', (t) async {
    final f = tasksFixture();
    await _open(t, f);
    await t.tap(find.widgetWithText(ActionChip, _l.peopleAdd).first);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'carol');
    await t.pumpAndSettle();
    expect(find.text('Carol'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);
  });

  testWidgets('a Jalali all-day due date is sent as UTC ISO', (t) async {
    final f = tasksFixture();
    await _open(t, f);
    await t.enterText(_titleField, 'Dated');
    await t.tap(find.byType(SwitchListTile));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('form-due')));
    await t.pumpAndSettle();
    await t.tap(find.text(toPersianDigits(15)).last);
    await t.pump();
    await t.tap(find.text(_l.jalaliPickerConfirm));
    await t.pumpAndSettle();
    await t.tap(_save);
    await t.pumpAndSettle();

    final today = toJalali(DateTime.now());
    final picked = jalaliToDateTime(today.year, today.month, 15);
    final body = f.server.lastBody('POST', '/tasks')! as Map;
    expect(body['due_at'], picked.toUtc().toIso8601String());
    expect(body['due_at'], endsWith('Z'));
    expect(body['all_day'], isTrue);
    expect(body.containsKey('start_at'), isFalse);
  });

  testWidgets('a due date before the start date is rejected', (t) async {
    final f = tasksFixture();
    await _open(t, f);
    await t.enterText(_titleField, 'Backwards');
    await t.tap(find.byType(SwitchListTile));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('form-start')));
    await t.pumpAndSettle();
    await t.tap(find.text(toPersianDigits(20)).last);
    await t.pump();
    await t.tap(find.text(_l.jalaliPickerConfirm));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('form-due')));
    await t.pumpAndSettle();
    await t.tap(find.text(toPersianDigits(10)).last);
    await t.pump();
    await t.tap(find.text(_l.jalaliPickerConfirm));
    await t.pumpAndSettle();
    await t.tap(_save);
    await t.pumpAndSettle();
    expect(find.text(_l.formDueBeforeStart), findsOneWidget);
    expect(f.server.where('POST', '/tasks'), isEmpty);
  });

  testWidgets('checklist items and priority are part of the create body', (
    t,
  ) async {
    final f = tasksFixture();
    await _open(t, f);
    await t.enterText(_titleField, 'With steps');
    await t.tap(find.widgetWithText(ChoiceChip, _l.taskPriorityHigh));
    await t.pump();
    await t.enterText(
      find.byKey(const ValueKey('form-checklist-input')),
      'one',
    );
    await t.tap(find.byTooltip(_l.checklistAdd));
    await t.pump();
    await t.enterText(
      find.byKey(const ValueKey('form-checklist-input')),
      'two',
    );
    await t.tap(find.byTooltip(_l.checklistAdd));
    await t.pump();
    await t.tap(_save);
    await t.pumpAndSettle();
    final body = f.server.lastBody('POST', '/tasks')! as Map;
    expect(body['checklist'], ['one', 'two']);
    expect(body['priority'], 'high');
  });

  testWidgets('labels from the server can be chosen', (t) async {
    final server = FakeTasksServer()
      ..labels.add({
        'id': 5,
        'name': 'Finance',
        'color': 1,
        'scope': 'org',
        'active': true,
      });
    final f = tasksFixture(server: server);
    await _open(t, f);
    await t.enterText(_titleField, 'Labelled');
    await t.tap(find.widgetWithText(FilterChip, 'Finance'));
    await t.pump();
    await t.tap(_save);
    await t.pumpAndSettle();
    expect((f.server.lastBody('POST', '/tasks')! as Map)['label_ids'], [5]);
  });

  testWidgets('a successful create pops with the new task', (t) async {
    final f = tasksFixture();
    final h = await _open(t, f);
    await t.enterText(_titleField, 'Pop me');
    await t.tap(_save);
    await t.pumpAndSettle();
    expect(h.popped, isTrue);
    expect(h.result?.title, 'Pop me');
  });

  testWidgets('a server error keeps the form open', (t) async {
    final f = tasksFixture();
    final h = await _open(t, f);
    await t.enterText(_titleField, 'Fails');
    f.server.failNext = 500;
    await t.tap(_save);
    await t.pumpAndSettle();
    expect(h.popped, isFalse);
    expect(find.text('boom'), findsOneWidget);
  });

  group('edit', () {
    TaskOut task({Map<String, dynamic>? can}) => TaskOut.fromJson(
      fullTask('t1', title: 'Old title', version: 7, can: can),
    );

    testWidgets('prefills and patches only what changed with the version', (
      t,
    ) async {
      final f = tasksFixture(
        server: FakeTasksServer(
          tasks: [fullTask('t1', title: 'Old title', version: 7)],
        ),
      );
      final h = await _open(t, f, task: task());
      expect(t.widget<TextField>(_titleField).controller?.text, 'Old title');
      expect(find.byKey(const ValueKey('form-checklist-input')), findsNothing);
      await t.enterText(_titleField, 'New title');
      await t.tap(_save);
      await t.pumpAndSettle();
      expect(f.server.lastBody('PATCH', '/tasks/t1'), {
        'version': 7,
        'title': 'New title',
      });
      expect(f.server.where('PUT', '/people'), isEmpty);
      expect(h.result?.title, 'New title');
    });

    testWidgets('changing followers also saves people with the new version', (
      t,
    ) async {
      final f = tasksFixture(
        server: FakeTasksServer(
          tasks: [fullTask('t1', title: 'Old title', version: 7)],
        ),
      );
      await _open(t, f, task: task());
      await t.tap(find.widgetWithText(ActionChip, _l.peopleAdd).last);
      await t.pumpAndSettle();
      await t.tap(find.text('Bob'));
      await t.tap(find.text(_l.commonConfirm));
      await t.pumpAndSettle();
      await t.tap(_save);
      await t.pumpAndSettle();
      final body = f.server.lastBody('PUT', '/people')! as Map;
      expect(body['follower_ids'], [3]);
      expect(body['version'], 7);
      expect(f.server.where('PATCH', '/tasks/t1'), isEmpty);
    });

    testWidgets('a 409 keeps the form open and explains', (t) async {
      final f = tasksFixture(
        server: FakeTasksServer(
          tasks: [fullTask('t1', title: 'Old title', version: 7)],
        ),
      );
      final h = await _open(t, f, task: task());
      f.server.conflictNext = true;
      await t.enterText(_titleField, 'Changed');
      await t.tap(_save);
      await t.pumpAndSettle();
      expect(h.popped, isFalse);
      expect(find.text(_l.taskConflict), findsOneWidget);
    });

    testWidgets('people pickers are hidden without edit rights', (t) async {
      final f = tasksFixture();
      await _open(t, f, task: task(can: canJson(progress: true)));
      expect(find.text(_l.fieldOwners), findsNothing);
    });
  });

  for (final size in const [Size(375, 812), Size(844, 390)]) {
    testWidgets(
      'form renders without overflow at ${size.width}x${size.height}',
      (t) async {
        final f = tasksFixture();
        await _open(t, f, size: size);
        expect(t.takeException(), isNull);
        await t.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }
}
