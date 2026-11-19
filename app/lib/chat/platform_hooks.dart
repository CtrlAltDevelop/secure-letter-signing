import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:record/record.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/workspace/file_pick.dart';

/// Reads an image from the system clipboard as a PNG; null when it holds none.
Future<PickedFile?> readSystemClipboardImage() async {
  final bytes = await Pasteboard.image;
  if (bytes == null || bytes.isEmpty) return null;
  return PickedFile(
    name: 'clipboard.png',
    bytes: bytes,
    contentType: 'image/png',
  );
}

/// Opens a small recorder dialog (microphone, timer, stop/cancel) and returns the finished
/// AAC recording; null when cancelled or the microphone is not allowed.
Future<PickedFile?> recordSystemVoice(BuildContext context) =>
    showDialog<PickedFile>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RecorderDialog(),
    );

class _RecorderDialog extends StatefulWidget {
  const _RecorderDialog();

  @override
  State<_RecorderDialog> createState() => _RecorderDialogState();
}

class _RecorderDialogState extends State<_RecorderDialog> {
  final AudioRecorder _rec = AudioRecorder();
  Timer? _tick;
  String? _path;
  int _seconds = 0;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (!await _rec.hasPermission()) {
      if (mounted) setState(() => _denied = true);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(const RecordConfig(), path: path);
    _path = path;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _finish({required bool send}) async {
    _tick?.cancel();
    final path = await _rec.stop() ?? _path;
    await _rec.dispose();
    PickedFile? out;
    if (send && path != null) {
      final file = File(path);
      out = PickedFile(
        name: 'voice.m4a',
        bytes: await file.readAsBytes(),
        contentType: 'audio/mp4',
      );
    }
    if (path != null) {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    }
    if (mounted) Navigator.pop(context, out);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return AlertDialog(
      title: Text(l.chatVoice),
      content: _denied
          ? Text(l.chatVoiceDenied)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fiber_manual_record, color: Colors.red),
                const SizedBox(width: 8),
                Text('$mm:$ss', textDirection: TextDirection.ltr),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => unawaited(_finish(send: false)),
          child: Text(l.commonCancel),
        ),
        if (!_denied)
          FilledButton(
            key: const ValueKey('voice-send'),
            onPressed: _seconds < 1
                ? null
                : () => unawaited(_finish(send: true)),
            child: Text(l.chatVoiceSend),
          ),
      ],
    );
  }
}
