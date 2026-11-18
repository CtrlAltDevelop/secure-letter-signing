import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart';

import 'fakes.dart';

class FakeChannel implements LiveChannel {
  final incoming = StreamController<dynamic>();
  final sent = <String>[];
  @override
  int? closeCode;
  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  Future<void> get ready async {}
  @override
  void send(String text) => sent.add(text);
  @override
  Future<void> close() async {
    if (!incoming.isClosed) await incoming.close();
  }

  Future<void> drop([int? code]) async {
    closeCode = code;
    await incoming.close();
  }
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late List<Uri> uris;
  late List<FakeChannel> channels;
  late List<Duration> delays;

  LiveService make(CursorStore cursor) {
    final f = fakeApi((_, _) => json({}));
    return LiveService(
      api: f.client,
      cursor: cursor,
      channelFactory: (uri) {
        uris.add(uri);
        final c = FakeChannel();
        channels.add(c);
        return c;
      },
      delay: (d) async => delays.add(d),
    );
  }

  setUp(() {
    uris = [];
    channels = [];
    delays = [];
  });

  test('socket uri swaps the scheme and carries the token', () {
    expect(LiveService.socketUri('https://api.corp.test', 'T').toString(), 'wss://api.corp.test/ws/?token=T');
    expect(LiveService.socketUri('http://10.0.2.2:8000/', 'T').toString(), 'ws://10.0.2.2:8000/ws/?token=T');
  });

  test('sends the stored cursor, emits events, persists the newest event id', () async {
    final cursor = MemoryCursorStore();
    await cursor.write(5);
    final live = make(cursor)..start();
    final seen = <LiveEvent>[];
    live.events.listen(seen.add);
    await settle();
    expect(jsonDecode(channels.single.sent.single), {'after': 5});
    expect(uris.single.queryParameters['token'], 'tok');

    channels.single.incoming
      ..add(jsonEncode({'type': 'letter', 'event_id': 9, 'letter_id': 'L', 'kind': 'signed'}))
      ..add(jsonEncode({'type': 'notification', 'id': 3, 'kind': 'sign_request', 'title': 'x', 'data': {}}));
    await settle();
    expect(seen.map((e) => e.type), ['letter', 'notification']);
    expect(await cursor.read(), 9);
    await live.dispose();
  });

  test('reconnects after a drop with backoff and catches up from the cursor', () async {
    final cursor = MemoryCursorStore();
    final live = make(cursor)..start();
    await settle();
    channels[0].incoming.add(jsonEncode({'type': 'letter', 'event_id': 4, 'letter_id': 'L', 'kind': 'sent'}));
    await settle();
    await channels[0].drop();
    await settle();
    expect(channels.length, 2);
    expect(jsonDecode(channels[1].sent.single), {'after': 4});
    expect(delays, [const Duration(seconds: 1)]);
    await live.dispose();
  });

  test('backoff doubles while connections give nothing, capped', () async {
    final live = make(MemoryCursorStore())..start();
    for (var i = 0; i < 8; i++) {
      await settle();
      await channels.last.drop();
    }
    await settle();
    expect(delays.take(6), [for (final s in [1, 2, 4, 8, 16, 30]) Duration(seconds: s)]);
    expect(delays.every((d) => d <= const Duration(seconds: 30)), isTrue);
    await live.dispose();
  });

  test('close code 4401 ends the session without retrying', () async {
    final live = make(MemoryCursorStore())..start();
    await settle();
    await channels.single.drop(4401);
    await settle();
    expect(channels.length, 1);
    expect(live.sessionEnded, isTrue);
    await live.dispose();
  });
}
