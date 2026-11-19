import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/notes/models.dart';
import 'package:letter_signing/notes/note_editor_screen.dart';
import 'package:letter_signing/notes/notes_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import 'notes_fixtures.dart';

const _sizes = [Size(375, 812), Size(844, 390)];

Future<void> _list(WidgetTester t, FakeNotesServer s, Size size) async {
  await useTallSurface(t, size);
  await t.pumpWidget(faMaterial(home: NotesScreen(env: notesEnv(s).env)));
  await t.pumpAndSettle();
}

void main() {
  test('NoteFilter builds the query and flags filters', () {
    const f = NoteFilter(q: 'a', labelId: 3, archived: true);
    final q = f.toQuery();
    expect(q['q'], 'a');
    expect(q['label'], 3);
    expect(q['archived'], 'true');
    expect(f.filtered, isTrue);
    expect(const NoteFilter().toQuery()['archived'], isNull);
  });

  for (final size in _sizes) {
    testWidgets('list shows pinned section first at $size', (t) async {
      final s = FakeNotesServer()
        ..notes.addAll([
          noteJson('a', title: 'Plain'),
          noteJson('b', title: 'Pinned one', pinned: true, color: 3),
        ]);
      await _list(t, s, size);
      expect(find.text('سنجاق‌شده'), findsOneWidget);
      expect(find.text('سایر'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('Pinned one')).dy <
            t.getTopLeft(find.text('Plain')).dy,
        isTrue,
      );
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('search, label chip and archive toggle reach the server', (
    t,
  ) async {
    final s = FakeNotesServer()
      ..notes.addAll([
        noteJson('a', title: 'Budget'),
        noteJson('b', title: 'Old', archived: true),
      ]);
    await _list(t, s, const Size(375, 812));
    await t.enterText(find.byType(TextField), 'bud');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(s.where('GET', '/notes').last.url.queryParameters['q'], 'bud');
    await t.tap(find.text('Work'));
    await t.pumpAndSettle();
    expect(s.where('GET', '/notes').last.url.queryParameters['label'], '1');
    await t.tap(find.byTooltip('آرشیو'));
    await t.pumpAndSettle();
    expect(
      s.where('GET', '/notes').last.url.queryParameters['archived'],
      'true',
    );
  });

  testWidgets('empty state', (t) async {
    await _list(t, FakeNotesServer(), const Size(375, 812));
    expect(find.text('یادداشتی ندارید'), findsOneWidget);
  });

  testWidgets('new note: checklist, colour, pin and save post one body', (
    t,
  ) async {
    final s = FakeNotesServer();
    await _list(t, s, const Size(375, 812));
    await t.tap(find.text('یادداشت جدید'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('note-title')), 'T');
    await t.enterText(find.byKey(const ValueKey('note-body')), 'B');
    await t.enterText(find.byKey(const ValueKey('note-item-input')), 'one');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.enterText(find.byKey(const ValueKey('note-item-input')), 'two');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    await t.tap(find.byTooltip('انتقال به بالا').last);
    await t.tap(find.byKey(const ValueKey('note-color-4')));
    await t.tap(find.byTooltip('سنجاق کردن'));
    await t.pump();
    await t.tap(find.text('ذخیره'));
    await t.pumpAndSettle();
    final body = s.lastBody('POST', '/notes')! as Map;
    expect(body['title'], 'T');
    expect(body['color'], 4);
    expect(body['pinned'], true);
    expect(body['checklist'], ['two', 'one']);
    expect(find.text('T'), findsOneWidget);
  });

  testWidgets('saved note: ticks, adds and reorders go to the server at once', (
    t,
  ) async {
    final s = FakeNotesServer()
      ..notes.add(
        noteJson(
          'n1',
          title: 'List',
          items: [itemJson(1, 'a'), itemJson(2, 'b')],
        ),
      );
    final n = NoteOut.fromJson(s.notes.first);
    await useTallSurface(t, const Size(375, 900));
    await t.pumpWidget(
      faMaterial(
        home: NoteEditorScreen(env: notesEnv(s).env, note: n),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(Checkbox).first);
    await t.pumpAndSettle();
    expect(s.lastBody('PATCH', '/checklist/1'), {'done': true});
    await t.tap(find.byTooltip('انتقال به پایین').first);
    await t.pumpAndSettle();
    expect(s.lastBody('PUT', '/checklist/order'), {
      'item_ids': [2, 1],
    });
    await t.tap(find.byTooltip('حذف مورد').first);
    await t.pumpAndSettle();
    expect(s.lastBody('PATCH', '/checklist/2'), {'active': false});
    await t.enterText(find.byKey(const ValueKey('note-item-input')), 'c');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(s.lastBody('POST', '/checklist'), {'text': 'c'});
  });

  testWidgets(
    'images: saved note uploads and shows a thumbnail, max enforced',
    (t) async {
      final s = FakeNotesServer()..notes.add(noteJson('n1'));
      final n = NoteOut.fromJson(s.notes.first);
      await useTallSurface(t, const Size(375, 900));
      await t.pumpWidget(
        faMaterial(
          home: NoteEditorScreen(
            env: notesEnv(s, pick: pickImage).env,
            note: n,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('افزودن تصویر'));
      await t.pumpAndSettle();
      expect(s.where('POST', '/subjects/ns-n1/files'), hasLength(1));
      expect(find.byKey(const ValueKey('note-image-f100')), findsOneWidget);
      await t.tap(find.byTooltip('حذف تصویر'));
      await t.pumpAndSettle();
      expect(s.where('DELETE', '/files/f100'), hasLength(1));
    },
  );

  testWidgets('a non-image pick is refused', (t) async {
    final s = FakeNotesServer()..notes.add(noteJson('n1'));
    final n = NoteOut.fromJson(s.notes.first);
    await useTallSurface(t, const Size(375, 900));
    await t.pumpWidget(
      faMaterial(
        home: NoteEditorScreen(
          env: notesEnv(s, pick: pickPdf).env,
          note: n,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('افزودن تصویر'));
    await t.pumpAndSettle();
    expect(find.text('فقط پرونده تصویر مجاز است.'), findsOneWidget);
    expect(s.where('POST', '/files'), isEmpty);
  });

  testWidgets('archive pops and calls the archive endpoint', (t) async {
    final s = FakeNotesServer()..notes.add(noteJson('n1', title: 'X'));
    await _list(t, s, const Size(375, 812));
    await t.tap(find.text('X'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('بایگانی'));
    await t.pumpAndSettle();
    expect(s.lastBody('POST', '/archive'), {'archived': true});
    expect(find.text('X'), findsNothing);
  });
}
