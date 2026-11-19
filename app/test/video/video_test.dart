import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:letter_signing/video/video_api.dart';
import 'package:letter_signing/video/video_call_button.dart';
import 'package:letter_signing/video/video_room_screen.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import '../prefs/ws_harness.dart';

Object? joinBody;

Ws _server({required bool enabled}) => ws((req, body) {
  final p = pathOf(req);
  if (p == '/video/config') return json({'enabled': enabled});
  if (p == '/video/join') {
    joinBody = body;
    return enabled
        ? json({'url': 'wss://x', 'token': 't', 'room': 'r', 'identity': 'i'})
        : json({'detail': 'off'}, 503);
  }
  return json({});
});

void main() {
  test('enabled mirrors /video/config and is cached', () async {
    final w = _server(enabled: true);
    final api = VideoApi(w.api);
    expect(await api.enabled(), isTrue);
    expect(await api.enabled(), isTrue);
    expect(w.where('GET', '/video/config'), hasLength(1));
  });

  test('join returns the room credentials', () async {
    final w = _server(enabled: true);
    final join = await VideoApi(w.api).join('s1');
    expect((join.url, join.token, join.room), ('wss://x', 't', 'r'));
    expect(joinBody, {'subject_id': 's1'});
  });

  testWidgets('the call button stays hidden when meetings are off', (t) async {
    final w = _server(enabled: false);
    await t.pumpWidget(
      faMaterial(
        home: Scaffold(
          appBar: AppBar(
            actions: [VideoCallButton(api: VideoApi(w.api), subjectId: 's1')],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('video-call')), findsNothing);
  });

  testWidgets('the call button shows when enabled', (t) async {
    final w = _server(enabled: true);
    await t.pumpWidget(
      faMaterial(
        home: Scaffold(
          appBar: AppBar(
            actions: [VideoCallButton(api: VideoApi(w.api), subjectId: 's1')],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('video-call')), findsOneWidget);
  });

  testWidgets('a 503 from join shows the not-configured message', (t) async {
    final w = _server(enabled: false);
    await t.pumpWidget(
      faMaterial(
        home: VideoRoomScreen(api: VideoApi(w.api), subjectId: 's1'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('جلسه آنلاین روی این سرور فعال نیست.'), findsOneWidget);
    expect(find.byKey(const ValueKey('video-retry')), findsOneWidget);
  });
}
