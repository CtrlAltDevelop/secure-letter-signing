import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/chat_text.dart';
import 'package:letter_signing/chat/conversation_controller.dart';
import 'package:letter_signing/chat/conversations_controller.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome;

import '../letters/fakes.dart' show FakeLive;
import 'chat_fixtures.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('chatSpans', () {
    const base = TextStyle();
    const mention = TextStyle(color: Color(0xFF0000FF));

    List<InlineSpan> spans(String t, [List<String> names = const []]) =>
        chatSpans(t, base: base, mentionStyle: mention, mentionNames: names);

    test('renders bold, italic and mentions as styled spans', () {
      final out = spans('a *bold* and _it_ @Sara Z ok', ['Sara Z']);
      final styled = out.cast<TextSpan>();
      expect(styled.map((s) => s.text), [
        'a ',
        'bold',
        ' and ',
        'it',
        ' ',
        '@Sara Z',
        ' ok',
      ]);
      expect(styled[1].style?.fontWeight, FontWeight.bold);
      expect(styled[3].style?.fontStyle, FontStyle.italic);
      expect(styled[5].style, mention);
    });

    test('leaves snake_case, lone markers and unknown mentions literal', () {
      expect(spans('snake_case_word').length, 1);
      expect(spans('2 * 3 * 4').length, 1);
      expect(spans('@Nobody hi').length, 1);
    });

    test('mentionedIds keeps only names still in the text', () {
      expect(mentionedIds('hi @Ali', {3: 'Sara', 4: 'Ali'}), [4]);
    });
  });

  group('ConversationsController', () {
    test('lists pinned first and counts unread of unmuted chats', () async {
      final s = FakeChatServer()
        ..conversations.addAll([
          convJson('a', name: 'Old', unread: 2, lastAt: '2026-01-01T00:00:00Z'),
          convJson('b', name: 'New', unread: 1, muted: true),
          convJson(
            'p',
            name: 'Pinned',
            pinned: true,
            lastAt: '2025-01-01T00:00:00Z',
          ),
        ]);
      final e = chatEnv(s);
      final c = ConversationsController(
        api: e.env.api,
        live: e.live,
        userId: 2,
      );
      await c.load();
      expect(c.items.map((x) => x.id), ['p', 'b', 'a']);
      expect(c.totalUnread, 2);
      c.dispose();
    });

    test('a live message bumps unread and preview, my own does not', () async {
      final s = FakeChatServer()
        ..conversations.add(convJson('a', lastSeq: 5, lastReadSeq: 5));
      final e = chatEnv(s);
      final c = ConversationsController(
        api: e.env.api,
        live: e.live,
        userId: 2,
      );
      await c.load();
      e.live.push(
        chatFrame('chat.message', 'a', {
          'seq': 6,
          'author_id': 3,
          'preview': 'سلام',
        }),
      );
      await settle();
      expect(c.items.single.unread, 1);
      expect(c.items.single.lastPreview, 'سلام');
      e.live.push(chatFrame('chat.message', 'a', {'seq': 7, 'author_id': 2}));
      await settle();
      expect(c.items.single.unread, 1);
      e.live.push(chatFrame('chat.read', 'a', {'seq': 7, 'user_id': 2}));
      await settle();
      expect(c.items.single.unread, 0);
      c.dispose();
    });

    test('public tab and search reach the server', () async {
      final s = FakeChatServer()
        ..conversations.add(
          convJson('pub', name: 'Open', isMember: false, isPublic: true),
        );
      final e = chatEnv(s);
      final c = ConversationsController(
        api: e.env.api,
        live: e.live,
        userId: 2,
      );
      await c.setFilter(const ConvFilter(publicOnly: true, q: 'op'));
      final url = s.calls.last.url;
      expect(url.queryParameters['public'], 'true');
      expect(url.queryParameters['q'], 'op');
      expect(c.items.single.canJoin, isTrue);
      c.dispose();
    });
  });

  group('ConversationController', () {
    Future<
      (ConversationController, FakeChatServer, ({ChatEnv env, FakeLive live}))
    >
    open({int count = 60}) async {
      final s = FakeChatServer()
        ..conversations.add(convJson('c1', lastSeq: count));
      s.messages['c1'] = [
        for (var i = 1; i <= count; i++)
          msgJson(
            i,
            i,
            text: 'm$i',
            at: '2026-03-${(i % 28 + 1).toString().padLeft(2, '0')}T10:00:00Z',
          ),
      ];
      final e = chatEnv(s);
      final c = ConversationController(
        api: e.env.api,
        live: e.live,
        userId: 2,
        conversationId: 'c1',
      );
      await c.load();
      return (c, s, e);
    }

    test('loads the latest page, pages older ones and marks read', () async {
      final (c, s, _) = await open();
      expect(c.messages.length, 50);
      expect(c.messages.last.seq, 60);
      expect(c.hasOlder, isTrue);
      await c.loadOlder();
      expect(c.messages.length, 60);
      expect(c.messages.first.seq, 1);
      expect(c.hasOlder, isFalse);
      await settle();
      expect((s.lastBody('POST', '/read') as Map)['seq'], 60);
      c.dispose();
    });

    test('send adds the message, carries reply and mentions', () async {
      final (c, s, _) = await open(count: 3);
      c.setReplyTo(c.messages.first);
      final out = await c.send(text: 'hi @Ali', mentions: [4]);
      expect(out, ActionOutcome.ok);
      expect(c.messages.last.text, 'hi @Ali');
      expect(c.replyTo, isNull);
      final body = s.lastBody('POST', '/messages') as Map;
      expect(body['reply_to_id'], 1);
      expect(body['mentions'], [4]);
      c.dispose();
    });

    test('delete swaps in the tombstone', () async {
      final (c, _, _) = await open(count: 3);
      await c.delete(c.messages.last);
      expect(c.messages.last.deleted, isTrue);
      expect(c.messages.last.text, '');
      c.dispose();
    });

    test('jumpToDate sends the day and shows that window', () async {
      final (c, s, _) = await open(count: 28);
      expect(await c.jumpToDate(DateTime(2026, 3, 10)), isTrue);
      expect(s.calls.last.url.queryParameters['around_date'], '2026-03-10');
      expect(c.windowJumps, 1);
      expect(await c.jumpToDate(DateTime(2030, 1, 1)), isFalse);
      c.dispose();
    });

    test('a live message is fetched and read, receipts are tracked', () async {
      final (c, s, e) = await open(count: 3);
      s.messages['c1']!.add(msgJson(99, 4, text: 'new one'));
      e.live.push(chatFrame('chat.message', 'c1', {'seq': 4, 'author_id': 3}));
      await settle();
      await settle();
      expect(c.messages.last.text, 'new one');
      e.live.push(chatFrame('chat.read', 'c1', {'seq': 4, 'user_id': 3}));
      await settle();
      expect(c.readSeqOf(3), 4);
      c.dispose();
    });

    test('bookmark and pin go to the server', () async {
      final (c, s, _) = await open(count: 2);
      await c.bookmark(c.messages.last);
      expect(s.lastBody('PUT', '/bookmarks'), {'module': 'chat', 'id': '2'});
      await c.setMessagePinned(c.messages.last, pinned: true);
      expect(c.messages.last.pinned, isTrue);
      expect(c.pins.length, 1);
      c.dispose();
    });

    test('sendFile uploads first, then posts a file message', () async {
      final (c, s, _) = await open(count: 1);
      final out = await c.sendFile(
        name: 'p.png',
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'image/png',
      );
      expect(out, ActionOutcome.ok);
      expect(s.where('POST', '/subjects/sub-c1/files'), hasLength(1));
      expect(c.messages.last.file?.isImage, isTrue);
      c.dispose();
    });
  });
}
