import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// What a client needs to join a LiveKit room (`POST /video/join`).
class VideoJoin {
  const VideoJoin({
    required this.url,
    required this.token,
    required this.room,
    required this.identity,
  });

  final String url;
  final String token;
  final String room;
  final String identity;

  factory VideoJoin.fromJson(Map<String, dynamic> j) => VideoJoin(
    url: asString(j['url']),
    token: asString(j['token']),
    room: asString(j['room']),
    identity: asString(j['identity']),
  );
}

/// `/video/config` and `/video/join`. A server without LiveKit answers 503 to `join`
/// ([ApiException]) and `enabled: false` to `config`; an older server 404s both.
class VideoApi {
  VideoApi(this.workspace);

  final WorkspaceApi workspace;
  Future<bool>? _enabled;

  /// Whether online meetings are available; cached, false on any failure.
  Future<bool> enabled() => _enabled ??= workspace
      .call('GET', '/video/config')
      .then((d) => asMap(d)['enabled'] == true)
      .catchError((Object _) => false);

  Future<VideoJoin> join(String subjectId) async => VideoJoin.fromJson(
    asMap(
      await workspace.call(
        'POST',
        '/video/join',
        body: {'subject_id': subjectId},
      ),
    ),
  );
}
