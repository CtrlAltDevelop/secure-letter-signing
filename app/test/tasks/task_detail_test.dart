import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/l10n/app_localizations_fa.dart';
import 'package:letter_signing/tasks/task_detail_screen.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import 'task_fixtures.dart';

final _l = AppLocalizationsFa();

Future<void> _pump(
  WidgetTester t,
  TasksFixture f, {
  Size size = const Size(800, 2400),
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    faApp(TaskDetailScreen(key: UniqueKey(), env: f.env, taskId: 't1')),
  );
  await t.pumpAndSettle();
}

TasksFixture _fixture(Map<String, dynamic> task, {PickedFile? picked}) =>
    tasksFixture(
      server: FakeTasksServer(tasks: [task]),
      picked: picked,
    );

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

final _dialogField = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

Finder _hint(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

Finder _tabChip(String prefix) => find.byWidgetPredicate(
  (w) =>
      w is ChoiceChip &&
      w.label is Text &&
      ((w.label as Text).data ?? '').startsWith(prefix),
);

void main() {
  group('action buttons follow can and status', () {
    final cases = <String, (Map<String, dynamic>, Set<String>)>{
      'owner of an open task': (
        fullTask('t1', can: canJson(edit: true, progress: true)),
        {_l.taskComplete, _l.taskCancel},
      ),
      'owner without edit': (
        fullTask('t1', can: canJson(progress: true)),
        {_l.taskComplete},
      ),
      'approver while awaiting': (
        fullTask(
          't1',
          status: 'awaiting_approval',
          can: canJson(approve: true),
        ),
        {_l.taskApprove, _l.taskReject},
      ),
      'creator of a done task': (
        fullTask('t1', status: 'done', can: canJson(edit: true)),
        {_l.taskReopen},
      ),
      'plain viewer': (fullTask('t1', can: canJson()), <String>{}),
    };
    final all = {
      _l.taskComplete,
      _l.taskApprove,
      _l.taskReject,
      _l.taskReopen,
      _l.taskCancel,
    };
    cases.forEach((name, spec) {
      testWidgets(name, (t) async {
        await _pump(t, _fixture(spec.$1));
        for (final label in all) {
          expect(
            _button(label),
            spec.$2.contains(label) ? findsOneWidget : findsNothing,
            reason: label,
          );
        }
      });
    });
  });

  testWidgets('opening a task marks it seen', (t) async {
    final f = _fixture(fullTask('t1', title: 'Budget'));
    await _pump(t, f);
    expect(find.text('Budget'), findsOneWidget);
    expect(f.server.where('POST', '/tasks/t1/seen').length, 1);
  });

  testWidgets('complete asks for an optional note and posts it', (t) async {
    final f = _fixture(fullTask('t1'));
    await _pump(t, f);
    await t.tap(_button(_l.taskComplete));
    await t.pumpAndSettle();
    await t.enterText(_dialogField, 'all done');
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: _button(_l.taskComplete),
      ),
    );
    await t.pumpAndSettle();
    expect(f.server.lastBody('POST', '/complete'), {'note': 'all done'});
    expect(find.text(_l.taskStatusDone), findsOneWidget);
  });

  testWidgets('reject needs a note before it can be sent', (t) async {
    final f = _fixture(
      fullTask('t1', status: 'awaiting_approval', can: canJson(approve: true)),
    );
    await _pump(t, f);
    await t.tap(_button(_l.taskReject));
    await t.pumpAndSettle();
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, _l.taskReject),
    );
    expect(t.widget<FilledButton>(confirm).onPressed, isNull);
    await t.enterText(_dialogField, 'not good enough');
    await t.pump();
    expect(t.widget<FilledButton>(confirm).onPressed, isNotNull);
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(f.server.lastBody('POST', '/decision'), {
      'decision': 'reject',
      'note': 'not good enough',
    });
  });

  testWidgets('approve sends the decision', (t) async {
    final f = _fixture(
      fullTask('t1', status: 'awaiting_approval', can: canJson(approve: true)),
    );
    await _pump(t, f);
    await t.tap(_button(_l.taskApprove));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: _button(_l.taskApprove),
      ),
    );
    await t.pumpAndSettle();
    expect(
      (f.server.lastBody('POST', '/decision')! as Map)['decision'],
      'approve',
    );
  });

  testWidgets('cancel asks for confirmation first', (t) async {
    final f = _fixture(fullTask('t1'));
    await _pump(t, f);
    await t.tap(_button(_l.taskCancel));
    await t.pumpAndSettle();
    await t.tap(find.text(_l.commonCancel));
    await t.pumpAndSettle();
    expect(f.server.where('POST', '/cancel'), isEmpty);

    await t.tap(_button(_l.taskCancel));
    await t.pumpAndSettle();
    await t.tap(find.text(_l.taskCancelYes));
    await t.pumpAndSettle();
    expect(f.server.where('POST', '/cancel').length, 1);
    expect(find.text(_l.taskStatusCancelled), findsOneWidget);
  });

  testWidgets('reopen is offered on a done task and posts', (t) async {
    final f = _fixture(
      fullTask('t1', status: 'done', can: canJson(edit: true)),
    );
    await _pump(t, f);
    await t.tap(_button(_l.taskReopen));
    await t.pumpAndSettle();
    expect(f.server.where('POST', '/reopen').length, 1);
    expect(find.text(_l.taskStatusOpen), findsOneWidget);
  });

  group('checklist', () {
    List<Map<String, dynamic>> items() => [
      checkItem(1, 'First'),
      checkItem(2, 'Second', done: true),
    ];

    testWidgets('ticking an item patches it', (t) async {
      final f = _fixture(fullTask('t1', items: items()));
      await _pump(t, f);
      await t.tap(find.byType(Checkbox).first);
      await t.pumpAndSettle();
      expect(f.server.lastBody('PATCH', '/checklist/1'), {'done': true});
      expect(
        t.widgetList<Checkbox>(find.byType(Checkbox)).map((c) => c.value),
        [true, true],
      );
    });

    testWidgets('a viewer without progress rights cannot tick', (t) async {
      final f = _fixture(fullTask('t1', items: items(), can: canJson()));
      await _pump(t, f);
      expect(t.widget<Checkbox>(find.byType(Checkbox).first).onChanged, isNull);
      expect(find.byKey(const ValueKey('checklist-add')), findsNothing);
    });

    testWidgets('adding an item posts its text', (t) async {
      final f = _fixture(fullTask('t1', items: items()));
      await _pump(t, f);
      await t.enterText(find.byKey(const ValueKey('checklist-add')), 'Third');
      await t.tap(find.byTooltip(_l.checklistAdd));
      await t.pumpAndSettle();
      expect(f.server.lastBody('POST', '/checklist'), {'text': 'Third'});
      expect(find.text('Third'), findsOneWidget);
    });

    testWidgets('removing an item deactivates it', (t) async {
      final f = _fixture(fullTask('t1', items: items()));
      await _pump(t, f);
      await t.tap(find.byTooltip(_l.checklistRemove).first);
      await t.pumpAndSettle();
      expect(f.server.lastBody('PATCH', '/checklist/1'), {'active': false});
      expect(find.text('First'), findsNothing);
    });

    testWidgets('dragging the handle reorders the items', (t) async {
      final f = _fixture(fullTask('t1', items: items()));
      await _pump(t, f);
      final handle = find.byIcon(Icons.drag_handle).first;
      final gesture = await t.startGesture(t.getCenter(handle));
      await t.pump(const Duration(milliseconds: 300));
      await gesture.moveBy(const Offset(0, 120));
      await t.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await t.pumpAndSettle();
      final body = f.server.lastBody('PUT', '/checklist/order')! as Map;
      expect(body['item_ids'], [2, 1]);
    });
  });

  testWidgets('progress slider only for owners in manual mode', (t) async {
    final owner = _fixture(fullTask('t1'));
    await _pump(t, owner);
    expect(find.byKey(const ValueKey('progress-slider')), findsOneWidget);

    final auto = _fixture(fullTask('t1', progressMode: 'checklist'));
    await _pump(t, auto);
    expect(find.byKey(const ValueKey('progress-slider')), findsNothing);
    expect(find.text(_l.taskProgressFromChecklist), findsOneWidget);
  });

  testWidgets('releasing the slider saves progress with the version', (
    t,
  ) async {
    final f = _fixture(fullTask('t1', version: 4));
    await _pump(t, f);
    final slider = find.byKey(const ValueKey('progress-slider'));
    await t.drag(slider, const Offset(150, 0));
    await t.pumpAndSettle();
    final body = f.server.lastBody('PATCH', '/tasks/t1')! as Map;
    expect(body['version'], 4);
    expect(body['progress'], greaterThan(0));
  });

  testWidgets('409 reloads the task and tells the user', (t) async {
    final f = _fixture(fullTask('t1', items: [checkItem(1, 'First')]));
    await _pump(t, f);
    final gets = f.server.where('GET', '/tasks/t1').length;
    f.server.conflictNext = true;
    await t.tap(find.byType(Checkbox).first);
    await t.pumpAndSettle();
    expect(find.text(_l.taskConflict), findsOneWidget);
    expect(f.server.where('GET', '/tasks/t1').length, gets + 1);
  });

  testWidgets('403 shows the permission message', (t) async {
    final f = _fixture(fullTask('t1'));
    await _pump(t, f);
    f.server.failNext = 403;
    await t.tap(_button(_l.taskComplete));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: _button(_l.taskComplete),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text(_l.taskForbidden), findsOneWidget);
  });

  group('comments', () {
    testWidgets('posting adds a comment', (t) async {
      final f = _fixture(fullTask('t1'));
      await _pump(t, f);
      expect(find.text(_l.commentsEmpty), findsOneWidget);
      await t.enterText(_hint(_l.commentHint), 'Looks good');
      await t.tap(find.byTooltip(_l.commentSend));
      await t.pumpAndSettle();
      final body = f.server.lastBody('POST', '/subjects/s-t1/comments')! as Map;
      expect((body['body'] as Map)['text'], 'Looks good');
      expect(body['kind'], 'comment');
      expect(find.text('Looks good'), findsOneWidget);
    });

    testWidgets('replying sends the parent id and nests the reply', (t) async {
      final f = _fixture(fullTask('t1'));
      f.server.comments.add(commentJson(1, 'Question?', author: bob));
      await _pump(t, f);
      await t.tap(find.text(_l.commentReply));
      await t.pump();
      expect(find.text(_l.commentReplyingTo('Bob')), findsOneWidget);
      await t.enterText(_hint(_l.commentHint), 'Answer');
      await t.tap(find.byTooltip(_l.commentSend));
      await t.pumpAndSettle();
      final body = f.server.lastBody('POST', '/subjects/s-t1/comments')! as Map;
      expect(body['parent_id'], 1);
      expect(find.text('Answer'), findsOneWidget);
      // Replies cannot be replied to again: only the parent shows a reply button.
      expect(find.text(_l.commentReply), findsOneWidget);
    });

    testWidgets('a report can carry a progress snapshot', (t) async {
      final f = _fixture(fullTask('t1'));
      await _pump(t, f);
      await t.tap(find.widgetWithText(ChoiceChip, _l.commentKindReport));
      await t.pump();
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await t.enterText(_hint(_l.commentHint), 'Half way');
      await t.tap(find.byTooltip(_l.commentSend));
      await t.pumpAndSettle();
      final body = f.server.lastBody('POST', '/subjects/s-t1/comments')! as Map;
      expect(body['kind'], 'report');
      expect(body['progress'], 50);
    });

    testWidgets('only own comments can be edited, and editing patches', (
      t,
    ) async {
      final f = _fixture(fullTask('t1'));
      f.server.comments
        ..add(commentJson(1, 'Mine'))
        ..add(commentJson(2, 'Theirs', author: bob));
      await _pump(t, f);
      expect(find.text(_l.commentEdit), findsOneWidget);
      await t.tap(find.text(_l.commentEdit));
      await t.pump();
      expect(find.text(_l.commentEditing), findsOneWidget);
      await t.enterText(_hint(_l.commentHint), 'Mine, revised');
      await t.tap(find.byTooltip(_l.commonSave));
      await t.pumpAndSettle();
      final body = f.server.lastBody('PATCH', '/comments/1')! as Map;
      expect((body['body'] as Map)['text'], 'Mine, revised');
      expect(find.text('Mine, revised'), findsOneWidget);
      expect(find.textContaining(_l.commentEdited), findsOneWidget);
    });

    testWidgets('deleting deactivates the comment', (t) async {
      final f = _fixture(fullTask('t1'));
      f.server.comments.add(commentJson(1, 'Mine'));
      await _pump(t, f);
      await t.tap(find.text(_l.commentDelete));
      await t.pumpAndSettle();
      expect(f.server.where('DELETE', '/comments/1').length, 1);
      expect(find.text('Mine'), findsNothing);
    });

    testWidgets('no composer without can.comment', (t) async {
      final f = _fixture(fullTask('t1', can: canJson(comment: false)));
      await _pump(t, f);
      expect(_hint(_l.commentHint), findsNothing);
    });

    testWidgets('a live comment event reloads the thread', (t) async {
      final f = _fixture(fullTask('t1'));
      await _pump(t, f);
      f.server.comments.add(commentJson(9, 'From a colleague', author: bob));
      f.live.push({
        'type': 'ws',
        'stream': 'w',
        'module': 'tasks',
        'kind': 'comment.created',
        'subject_id': 's-t1',
      });
      await t.pumpAndSettle();
      expect(find.text('From a colleague'), findsOneWidget);
    });
  });

  group('files', () {
    final picked = PickedFile(
      name: 'uploaded.pdf',
      bytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'application/pdf',
    );

    testWidgets('uploading posts multipart and lists the file', (t) async {
      final f = _fixture(fullTask('t1'), picked: picked);
      await _pump(t, f);
      await t.tap(_tabChip(_l.tabFiles));
      await t.pumpAndSettle();
      expect(find.text(_l.filesEmpty), findsOneWidget);
      await t.tap(find.text(_l.fileUpload));
      await t.pumpAndSettle();
      expect(f.server.where('POST', '/subjects/s-t1/files').length, 1);
      expect(find.text('uploaded.pdf'), findsOneWidget);
    });

    testWidgets('downloading hands the bytes to saveFile', (t) async {
      final f = _fixture(fullTask('t1'));
      f.server.files.add(fileJson('f1', 'report.pdf'));
      await _pump(t, f);
      await t.tap(_tabChip(_l.tabFiles));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip(_l.fileDownload));
      await t.pumpAndSettle();
      expect(f.saved, ['report.pdf']);
    });

    testWidgets('only the uploader can deactivate a file', (t) async {
      final f = _fixture(fullTask('t1'));
      f.server.files
        ..add(fileJson('f1', 'mine.pdf'))
        ..add(fileJson('f2', 'theirs.pdf', uploader: 3));
      await _pump(t, f);
      await t.tap(_tabChip(_l.tabFiles));
      await t.pumpAndSettle();
      expect(find.byTooltip(_l.fileDelete), findsOneWidget);
      await t.tap(find.byTooltip(_l.fileDelete));
      await t.pumpAndSettle();
      expect(f.server.where('DELETE', '/files/f1').length, 1);
      expect(find.text('mine.pdf'), findsNothing);
      expect(find.text('theirs.pdf'), findsOneWidget);
    });
  });

  testWidgets('history tab shows the empty state', (t) async {
    final f = _fixture(fullTask('t1'));
    await _pump(t, f);
    await t.tap(_tabChip(_l.tabHistory));
    await t.pumpAndSettle();
    expect(find.text(_l.historyEmpty), findsOneWidget);
  });

  testWidgets('seen-by sheet lists who opened the task', (t) async {
    final f = _fixture(fullTask('t1'));
    await _pump(t, f);
    await t.tap(find.byTooltip(_l.seenByTitle));
    await t.pumpAndSettle();
    expect(find.text(_l.seenByEmpty), findsOneWidget);
  });

  testWidgets('approvers show their decisions', (t) async {
    final f = _fixture(
      fullTask(
        't1',
        status: 'awaiting_approval',
        approvers: [
          {'user': bob, 'position': 1, 'decision': 'approved'},
          {'user': carol, 'position': 2, 'decision': 'pending'},
        ],
      ),
    );
    await _pump(t, f);
    expect(find.text(_l.approverApproved), findsOneWidget);
    expect(find.text(_l.approverTurn), findsOneWidget);
  });

  testWidgets('a missing task shows the error state', (t) async {
    final f = tasksFixture();
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(800, 1200);
    addTearDown(t.view.reset);
    await t.pumpWidget(faApp(TaskDetailScreen(env: f.env, taskId: 'nope')));
    await t.pumpAndSettle();
    expect(find.text(_l.taskLoadFailed), findsOneWidget);
  });

  for (final size in const [Size(375, 812), Size(844, 390)]) {
    testWidgets(
      'detail renders without overflow at ${size.width}x${size.height}',
      (t) async {
        final f = _fixture(
          fullTask(
            't1',
            title: 'A long task title that needs more than one line to show',
            description: 'Some description\nwith several\nlines of text',
            items: [
              checkItem(1, 'First step'),
              checkItem(2, 'Second', done: true),
            ],
            approvers: [
              {'user': bob, 'position': 1, 'decision': 'pending'},
            ],
            status: 'awaiting_approval',
            can: canJson(edit: true, progress: true, approve: true),
            dueAt: '2020-01-01T10:00:00Z',
          ),
        );
        f.server.comments.add(
          commentJson(
            1,
            'Hello there',
            author: bob,
            replies: [commentJson(2, 'Hi')],
          ),
        );
        await _pump(t, f, size: size);
        expect(t.takeException(), isNull);
        await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.scrollUntilVisible(
          _tabChip(_l.tabFiles),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await t.tap(_tabChip(_l.tabFiles));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }
}
