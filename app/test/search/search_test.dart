import 'package:material_ui/material_ui.dart' show Icons, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/bookmarks/bookmarks_api.dart';
import 'package:letter_signing/bookmarks/bookmarks_screen.dart';
import 'package:letter_signing/bookmarks/pinned_screen.dart';
import 'package:letter_signing/search/search_api.dart';
import 'package:letter_signing/search/search_screen.dart';
import 'package:letter_signing/workspace/open_target.dart';
import 'package:letter_signing/workspace/widgets/bookmark_button.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import '../prefs/ws_harness.dart';

Map<String, dynamic> _hit(
  String module,
  String id,
  String title, {
  String kind = 'x',
}) => {
  'module': module,
  'kind': kind,
  'id': id,
  'subject_id': 's-$id',
  'title': title,
  'snippet': 'snip',
  'at': null,
};

void main() {
  testWidgets('search groups hits by module and opens the tapped one', (
    t,
  ) async {
    await useTallSurface(t);
    final w = ws((req, _) {
      if (pathOf(req) == '/search') {
        return json([
          _hit('tasks', '1', 'Task one'),
          _hit('letters', '2', 'Letter two'),
          _hit('files', 'f1', 'report.pdf', kind: 'file'),
        ]);
      }
      return json(<Object>[]);
    });
    final opened = <OpenTarget>[];
    await t.pumpWidget(
      faMaterial(
        home: SearchScreen(
          api: SearchApi(w.api),
          open: (c, x) async => opened.add(x),
        ),
      ),
    );
    await t.enterText(find.byKey(const ValueKey('search-field')), 'a');
    await t.pump(const Duration(seconds: 1));
    expect(w.where('GET', '/search'), isEmpty); // too short
    await t.enterText(find.byKey(const ValueKey('search-field')), 'abc');
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.text('Task one'), findsOneWidget);
    expect(find.text('report.pdf'), findsOneWidget);
    await t.tap(find.text('Letter two'));
    expect(opened.single.module, 'letters');
    expect(opened.single.id, '2');
    await t.tap(find.byKey(const ValueKey('search-chip-tasks')));
    await t.pumpAndSettle();
    expect(w.where('GET', 'modules=tasks'), isNotEmpty);
  });

  testWidgets('rate limit shows its own message', (t) async {
    final w = ws((req, _) => json({'detail': 'slow'}, 429));
    await t.pumpWidget(
      faMaterial(
        home: SearchScreen(api: SearchApi(w.api), open: (c, x) async {}),
      ),
    );
    await t.enterText(find.byKey(const ValueKey('search-field')), 'abc');
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.textContaining('زیاد'), findsOneWidget);
  });

  testWidgets('bookmark button toggles with PUT and DELETE', (t) async {
    final w = ws((req, _) {
      final p = pathOf(req);
      if (req.method == 'GET' && p == '/bookmarks') return json(<Object>[]);
      if (req.method == 'PUT') {
        return json({
          'id': 7,
          'module': 'tasks',
          'kind': 'task',
          'target_id': 's-1',
          'object_id': '1',
          'title': 'T',
        });
      }
      return json(null, 204);
    });
    await t.pumpWidget(
      faApp(BookmarkButton(api: w.api, module: 'tasks', id: '1')),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('bookmark-button')));
    await t.pumpAndSettle();
    expect(w.where('PUT', '/bookmarks'), hasLength(1));
    await t.tap(find.byKey(const ValueKey('bookmark-button')));
    await t.pumpAndSettle();
    expect(w.where('DELETE', '/bookmarks/7'), hasLength(1));
  });

  testWidgets('bookmark button starts filled when already bookmarked', (
    t,
  ) async {
    final w = ws(
      (req, _) => json([
        {
          'id': 3,
          'module': 'letters',
          'kind': 'letter',
          'target_id': 's-9',
          'object_id': '9',
          'title': 'L',
        },
      ]),
    );
    await t.pumpWidget(
      faApp(BookmarkButton(api: w.api, module: 'letters', id: '9')),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('bookmark-button')));
    await t.pumpAndSettle();
    expect(w.where('DELETE', '/bookmarks/3'), hasLength(1));
  });

  testWidgets('bookmarks screen lists, opens by object id and removes', (
    t,
  ) async {
    final w = ws((req, _) {
      if (req.method == 'GET') {
        return json([
          {
            'id': 3,
            'module': 'tasks',
            'kind': 'task',
            'target_id': 's-9',
            'object_id': '9',
            'title': 'Pay rent',
          },
          {
            'id': 4,
            'module': 'chat',
            'kind': 'message',
            'target_id': '55',
            'title': 'Team',
          },
        ]);
      }
      return json(null, 204);
    });
    final opened = <OpenTarget>[];
    await t.pumpWidget(
      faMaterial(
        home: BookmarksScreen(
          api: BookmarksApi(w.api),
          open: (c, x) async => opened.add(x),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Pay rent'));
    expect(opened.single.id, '9');
    await t.tap(find.byKey(const ValueKey('bm-filter-chat')));
    await t.pumpAndSettle();
    expect(find.text('Pay rent'), findsNothing);
    await t.tap(find.byIcon(Icons.bookmark));
    await t.pumpAndSettle();
    expect(w.where('DELETE', '/bookmarks/4'), hasLength(1));
  });

  testWidgets('pinned screen lists pins and opens by subject id', (t) async {
    final w = ws(
      (req, _) => json([
        {
          'subject_id': 'sp',
          'module': 'projects',
          'kind': 'project',
          'title': 'Alpha',
        },
      ]),
    );
    final opened = <OpenTarget>[];
    await t.pumpWidget(
      faApp(
        PinnedScreen(
          api: BookmarksApi(w.api),
          open: (c, x) async => opened.add(x),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Alpha'));
    expect(opened.single.kind, 'subject');
    expect(opened.single.subjectId, 'sp');
  });
}
