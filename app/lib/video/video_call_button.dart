import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/video/video_api.dart';
import 'package:letter_signing/video/video_room_screen.dart';

/// App bar button that opens the online-meeting room of [subjectId]; hidden while the server
/// has no LiveKit configured.
class VideoCallButton extends StatefulWidget {
  const VideoCallButton({
    super.key,
    required this.api,
    required this.subjectId,
    this.title,
  });

  final VideoApi api;
  final String subjectId;
  final String? title;

  @override
  State<VideoCallButton> createState() => _VideoCallButtonState();
}

class _VideoCallButtonState extends State<VideoCallButton> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.api.enabled().then((v) {
        if (mounted && v) setState(() => _enabled = true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return const SizedBox.shrink();
    return IconButton(
      key: const ValueKey('video-call'),
      tooltip: AppLocalizations.of(context).videoJoin,
      icon: const Icon(Icons.video_call_outlined),
      onPressed: () => unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => VideoRoomScreen(
              api: widget.api,
              subjectId: widget.subjectId,
              title: widget.title,
            ),
          ),
        ),
      ),
    );
  }
}
