import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/chat/chat_panel.dart';
import 'package:letter_signing/chat/chat_screen.dart';
import 'package:letter_signing/chat/conversation_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import 'chat_fixtures.dart';

const _sizes = [Size(375, 812), Size(844, 390)];

FakeChatServer _server() {
  final s = FakeChatServer()
    ..conversations.addAll([
      convJson('c1', name: 'تیم فروش', unread: 3, lastSeq: 3, preview: 'سلام'),
      convJson(
        'c2',
        name: 'Pinned room',
        pinned: true,
        lastAt: '2025-01-01T00:00:00Z',
      ),
      convJson(
        'pub',
        name: 'Open channel',
        kind: 'channel',
        isMember: false,
        isPublic: true,
      ),
    ]);
  s.messages['c1'] = [
    msgJson(1, 1, text: 'first'),
    msgJson(2, 2, text: 'a *bold* word', authorName: 'Sara'),
    msgJson(3, 3, text: 'mine here', author: 2, authorName: 'Me'),
  ];
  return s;
}

Future<void> _openList(
  WidgetTester t,
  FakeChatServer s,
  Size size, {
  bool canCreate = true,
}) async {
  await useTallSurface(t, size);
  await t.pumpWidget(
    faMaterial(
      home: ChatScreen(env: chatEnv(s, canCreate: canCreate).env),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _openConv(
  WidgetTester t,
  FakeChatServer s, {
  String id = 'c1',
  Size size = const Size(375, 812),
}) async {
  await useTallSurface(t, size);
  final e = chatEnv(s);
  await t.pumpWidget(
    faMaterial(
      home: ConversationScreen(env: e.env, conversationId: id),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  for (final size in _sizes) {
    testWidgets('list shows pinned first with unread badge at $size', (
      t,
    ) async {
      final s = _server();
      await _openList(t, s, size);
      expect(find.text('Pinned room'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('Pinned room')).dy <
            t.getTopLeft(find.text('تیم فروش')).dy,
        isTrue,
      );
      expect(find.text('۳'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('public tab lists joinable conversations', (t) async {
    final s = _server();
    await _openList(t, s, const Size(375, 812));
    await t.tap(find.text('عمومی'));
    await t.pumpAndSettle();
    expect(find.text('Open channel'), findsOneWidget);
    expect(find.text('پیوستن'), findsOneWidget);
  });

  testWidgets('new menu hides group and channel without permission', (t) async {
    final s = _server();
    await _openList(t, s, const Size(375, 812), canCreate: false);
    await t.tap(find.text('گفتگوی جدید'));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.text('گروه جدید'), findsNothing);
  });

  for (final size in _sizes) {
    testWidgets('conversation renders messages and sends one at $size', (
      t,
    ) async {
      final s = _server();
      await _openConv(t, s, size: size);
      expect(find.text('first'), findsOneWidget);
      expect(find.text('mine here'), findsOneWidget);
      // The bold marker is rendered as a span, not as literal asterisks.
      expect(find.textContaining('*bold*', findRichText: true), findsNothing);
      await t.enterText(find.byType(TextField), 'new text');
      await t.tap(find.byIcon(Icons.send));
      await t.pumpAndSettle();
      expect((s.lastBody('POST', '/messages') as Map)['text'], 'new text');
      expect(find.text('new text'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('long press offers reply, bookmark, task, seen and delete', (
    t,
  ) async {
    final s = _server();
    await _openConv(t, s);
    await t.longPress(find.text('mine here'));
    await t.pumpAndSettle();
    expect(find.text('پاسخ'), findsOneWidget);
    expect(find.text('تبدیل به وظیفه'), findsOneWidget);
    expect(find.text('چه کسی دیده است'), findsOneWidget);
    await t.tap(find.text('نشان کردن'));
    await t.pumpAndSettle();
    expect(s.where('PUT', '/bookmarks'), hasLength(1));
  });

  testWidgets('seen sheet lists readers with time', (t) async {
    final s = _server();
    await _openConv(t, s);
    await t.longPress(find.text('mine here'));
    await t.pumpAndSettle();
    await t.tap(find.text('چه کسی دیده است'));
    await t.pumpAndSettle();
    expect(find.text('Sara'), findsWidgets);
    expect(s.where('GET', '/seen'), hasLength(1));
  });

  testWidgets('delete asks for confirmation then shows the tombstone', (
    t,
  ) async {
    final s = _server();
    await _openConv(t, s);
    await t.longPress(find.text('mine here'));
    await t.pumpAndSettle();
    await t.tap(find.text('حذف پیام'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'حذف پیام'));
    await t.pumpAndSettle();
    expect(find.text('این پیام حذف شد'), findsOneWidget);
  });

  testWidgets('reply banner shows and the reply id is sent', (t) async {
    final s = _server();
    await _openConv(t, s);
    await t.longPress(find.text('first'));
    await t.pumpAndSettle();
    await t.tap(find.text('پاسخ'));
    await t.pumpAndSettle();
    expect(find.text('پاسخ به Sara'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'ok');
    await t.tap(find.byIcon(Icons.send));
    await t.pumpAndSettle();
    expect((s.lastBody('POST', '/messages') as Map)['reply_to_id'], 1);
  });

  testWidgets('mention button inserts @name and sends the id', (t) async {
    final s = _server();
    await _openConv(t, s);
    await t.tap(find.byIcon(Icons.alternate_email));
    await t.pumpAndSettle();
    await t.tap(find.text('Ali'));
    await t.pumpAndSettle();
    expect(find.text('@Ali '), findsOneWidget);
    await t.tap(find.byIcon(Icons.send));
    await t.pumpAndSettle();
    final body = s.lastBody('POST', '/messages') as Map;
    expect(body['mentions'], [4]);
    expect(body['text'], '@Ali');
  });

  testWidgets('paste button inserts clipboard text', (t) async {
    final s = _server();
    await _openConv(t, s);
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': 'pasted'} : null,
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await t.tap(find.byIcon(Icons.content_paste));
    await t.pumpAndSettle();
    expect(find.text('pasted'), findsOneWidget);
  });

  testWidgets('pasted clipboard image uses the hook and uploads', (t) async {
    final s = _server();
    await useTallSurface(t, const Size(375, 812));
    final e = chatEnv(s, clipboardImage: pickImage);
    await t.pumpWidget(
      faMaterial(
        home: ConversationScreen(env: e.env, conversationId: 'c1'),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.content_paste));
    await t.pumpAndSettle();
    expect(s.where('POST', '/subjects/sub-c1/files'), hasLength(1));
    expect((s.lastBody('POST', '/messages') as Map)['file_id'], 'f1');
  });

  testWidgets('edit my message patches the text', (t) async {
    final s = _server();
    await _openConv(t, s);
    await t.longPress(find.text('mine here'));
    await t.pumpAndSettle();
    await t.tap(find.text('ویرایش پیام'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('chat-text-dialog')), 'fixed');
    await t.tap(find.byKey(const ValueKey('chat-text-dialog-ok')));
    await t.pumpAndSettle();
    expect((s.lastBody('PATCH', '/chat/messages/') as Map)['text'], 'fixed');
    expect(find.text('fixed'), findsOneWidget);
  });

  testWidgets('message to task posts to the server endpoint', (t) async {
    final s = _server();
    await _openConv(t, s);
    await t.longPress(find.text('mine here'));
    await t.pumpAndSettle();
    await t.tap(find.text('تبدیل به وظیفه'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('chat-text-dialog-ok')));
    await t.pumpAndSettle();
    expect(s.where('POST', '/to-task'), hasLength(1));
    expect((s.lastBody('POST', '/to-task') as Map)['title'], 'mine here');
  });

  testWidgets('search inside the conversation lists hits', (t) async {
    final s = _server();
    await _openConv(t, s);
    await t.tap(find.byKey(const ValueKey('chat-search')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('chat-search-field')), 'first');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(s.where('GET', '/chat/search'), hasLength(1));
    final hit = find.descendant(
      of: find.byType(ListTile),
      matching: find.text('first'),
    );
    expect(hit, findsOneWidget);
    await t.tap(hit);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-search-field')), findsNothing);
  });

  testWidgets('mic only in a DM with a recorder hook', (t) async {
    final s = _server()
      ..conversations.add(
        convJson('d1', kind: 'dm', name: 'Sara', other: userJson(3, 'Sara')),
      );
    s.messages['d1'] = [];
    await useTallSurface(t, const Size(375, 812));
    final e = chatEnv(s, record: (_) => pickImage());
    await t.pumpWidget(
      faMaterial(
        home: ConversationScreen(env: e.env, conversationId: 'd1'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.mic), findsOneWidget);
    await t.tap(find.byIcon(Icons.mic));
    await t.pumpAndSettle();
    expect((s.lastBody('POST', '/messages') as Map)['kind'], 'voice');
  });

  testWidgets('pins bar shows the pinned message', (t) async {
    final s = _server();
    s.messages['c1']![1]['pinned'] = true;
    await _openConv(t, s);
    expect(find.byIcon(Icons.push_pin), findsWidgets);
    expect(find.text('a *bold* word'), findsWidgets);
  });

  testWidgets('public non-member gets the join bar', (t) async {
    final s = _server();
    await _openConv(t, s, id: 'pub');
    expect(find.text('برای دیدن پیام‌ها ابتدا بپیوندید.'), findsOneWidget);
    await t.tap(find.text('پیوستن'));
    await t.pumpAndSettle();
    expect(s.where('POST', '/join'), hasLength(1));
  });

  testWidgets('project and customer chat tabs resolve the mirrored chat', (
    t,
  ) async {
    final s = _server();
    await useTallSurface(t, const Size(375, 812));
    final e = chatEnv(s);
    await t.pumpWidget(
      faMaterial(
        home: Scaffold(
          body: ProjectChatTab(env: e.env, projectId: 'p1'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(s.where('GET', '/projects/p1/chat'), hasLength(1));
    expect(find.text('first'), findsOneWidget);
    await t.pumpWidget(
      faMaterial(
        home: Scaffold(
          body: CustomerChatTab(env: e.env, customerId: 'u1'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(s.where('GET', '/customers/u1/chat'), hasLength(1));
  });
}
