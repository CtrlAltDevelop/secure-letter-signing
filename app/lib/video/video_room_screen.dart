import 'dart:async';

import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart' show ApiException;
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/video/video_api.dart';

/// Joins the LiveKit room of a subject (a meeting or a conversation): camera, microphone,
/// screen share and a tile grid. The server only mints the token; media goes to LiveKit.
class VideoRoomScreen extends StatefulWidget {
  const VideoRoomScreen({
    super.key,
    required this.api,
    required this.subjectId,
    this.title,
  });

  final VideoApi api;
  final String subjectId;
  final String? title;

  @override
  State<VideoRoomScreen> createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends State<VideoRoomScreen> {
  /// Created once the server issued a token (nothing to tear down before that).
  Room? _room;
  bool _connecting = true;
  Object? _error;
  bool _mic = true;
  bool _camera = true;
  bool _share = false;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final join = await widget.api.join(widget.subjectId);
      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _room = room;
      await room.connect(join.url, join.token);
      await room.localParticipant?.setMicrophoneEnabled(_mic);
      await room.localParticipant?.setCameraEnabled(_camera);
    } on Object catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _connecting = false);
  }

  @override
  void dispose() {
    final room = _room;
    if (room != null) {
      unawaited(_close(room));
    }
    super.dispose();
  }

  Future<void> _close(Room room) async {
    try {
      await room.disconnect();
      await room.dispose();
    } on Object {
      // Leaving: nothing left to report.
    }
  }

  Future<void> _toggleMic() async {
    _mic = !_mic;
    await _room?.localParticipant?.setMicrophoneEnabled(_mic);
    if (mounted) setState(() {});
  }

  Future<void> _toggleCamera() async {
    _camera = !_camera;
    await _room?.localParticipant?.setCameraEnabled(_camera);
    if (mounted) setState(() {});
  }

  Future<void> _toggleShare() async {
    final next = !_share;
    try {
      await _room?.localParticipant?.setScreenShareEnabled(next);
      if (mounted) setState(() => _share = next);
    } on Object {
      if (mounted) setState(() => _share = false);
    }
  }

  String _message(AppLocalizations l) =>
      _error is ApiException && (_error! as ApiException).status == 503
      ? l.videoNotConfigured
      : l.videoJoinFailed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? l.videoTitle)),
      body: _connecting
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(l.videoConnecting),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_message(l)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const ValueKey('video-retry'),
                    onPressed: () => unawaited(_connect()),
                    child: Text(l.videoRetry),
                  ),
                ],
              ),
            )
          : ListenableBuilder(
              listenable: _room!,
              builder: (context, _) => _grid(l),
            ),
      bottomNavigationBar: _connecting || _error != null ? null : _bar(l),
    );
  }

  Widget _grid(AppLocalizations l) {
    final room = _room!;
    final people = <Participant>[
      ?room.localParticipant,
      ...room.remoteParticipants.values,
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth > 700 ? 3 : (people.length > 1 ? 2 : 1);
        return GridView.count(
          crossAxisCount: columns,
          padding: const EdgeInsets.all(8),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 4 / 3,
          children: [
            for (final p in people)
              _Tile(
                key: ValueKey('video-tile-${p.identity}'),
                participant: p,
                isMe: p is LocalParticipant,
                youLabel: l.videoYou,
              ),
          ],
        );
      },
    );
  }

  Widget _bar(AppLocalizations l) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filledTonal(
            key: const ValueKey('video-mic'),
            tooltip: l.videoMic,
            icon: Icon(_mic ? Icons.mic : Icons.mic_off),
            onPressed: () => unawaited(_toggleMic()),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: const ValueKey('video-camera'),
            tooltip: l.videoCamera,
            icon: Icon(_camera ? Icons.videocam : Icons.videocam_off),
            onPressed: () => unawaited(_toggleCamera()),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: const ValueKey('video-share'),
            tooltip: l.videoShare,
            icon: Icon(_share ? Icons.stop_screen_share : Icons.screen_share),
            onPressed: () => unawaited(_toggleShare()),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const ValueKey('video-leave'),
            tooltip: l.videoLeave,
            style: IconButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.call_end),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.participant,
    required this.isMe,
    required this.youLabel,
  });

  final Participant participant;
  final bool isMe;
  final String youLabel;

  VideoTrack? get _track {
    final pubs =
        participant.videoTrackPublications
            .where((p) => !p.muted && p.track != null)
            .toList()
          ..sort(
            (a, b) => (b.source == TrackSource.screenShareVideo ? 1 : 0)
                .compareTo(a.source == TrackSource.screenShareVideo ? 1 : 0),
          );
    final track = pubs.firstOrNull?.track;
    return track is VideoTrack ? track : null;
  }

  @override
  Widget build(BuildContext context) {
    final name = participant.name.isEmpty
        ? participant.identity
        : participant.name;
    final track = _track;
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (track != null)
              VideoTrackRenderer(track, fit: VideoViewFit.contain)
            else
              Center(
                child: CircleAvatar(
                  radius: 28,
                  child: Text(name.isEmpty ? '?' : name.characters.first),
                ),
              ),
            PositionedDirectional(
              start: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (participant.isMuted)
                      const Icon(Icons.mic_off, size: 14, color: Colors.white),
                    Text(
                      isMe ? '$name ($youLabel)' : name,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
