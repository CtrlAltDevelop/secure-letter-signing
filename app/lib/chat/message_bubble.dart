import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/chat_text.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';

const _bubbleRadius = 14.0;
const _imageWidth = 220.0;

/// One message: author, quoted reply, attachment, styled text and a footer (time, edited, pin,
/// seen tick). Tombstones and system lines are drawn plainly.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.env,
    required this.message,
    required this.mine,
    required this.showAuthor,
    required this.nameOf,
    this.seenByOther = false,
    this.onActions,
    this.onReplyTap,
  });

  final ChatEnv env;
  final ChatMessage message;
  final bool mine;
  final bool showAuthor;
  final String? Function(int userId) nameOf;

  /// A DM peer's live read position covers this message.
  final bool seenByOther;
  final VoidCallback? onActions;
  final ValueChanged<ReplyRef>? onReplyTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12);
    if (message.isSystem) {
      final text = message.isTaskCreated || message.text.isEmpty
          ? l.chatTaskCreated
          : message.text;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(text, style: muted),
        ),
      );
    }
    final bg = mine ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final fg = mine ? scheme.onPrimaryContainer : scheme.onSurface;
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(_bubbleRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(_bubbleRadius),
            onTap: onActions,
            onLongPress: onActions,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showAuthor && !mine)
                    Text(
                      message.author.displayName,
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  if (message.replyTo != null && !message.deleted)
                    _Quote(
                      reply: message.replyTo!,
                      name: nameOf(message.replyTo!.authorId),
                      onTap: onReplyTap,
                    ),
                  if (message.deleted)
                    Text(
                      l.chatDeleted,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else ...[
                    if (message.file != null)
                      ChatFileView(env: env, file: message.file!),
                    if (message.text.isNotEmpty) _text(context, fg),
                  ],
                  const SizedBox(height: 2),
                  _footer(context, l, muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _text(BuildContext context, Color fg) {
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(color: fg);
    final names = [for (final id in message.mentions) ?nameOf(id)];
    return Text.rich(
      TextSpan(
        style: base,
        children: chatSpans(
          message.text,
          base: base,
          mentionStyle: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
          mentionNames: names,
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, AppLocalizations l, TextStyle muted) {
    final at = message.createdAt;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.pinned) Icon(Icons.push_pin, size: 12, color: muted.color),
        if (message.edited && !message.deleted)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: Text(l.chatEdited, style: muted),
          ),
        if (at != null) Text(formatJalaliTime(at), style: muted),
        if (seenByOther)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Icon(
              Icons.done_all,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
              semanticLabel: l.chatSeen,
            ),
          ),
      ],
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.reply, required this.name, this.onTap});
  final ReplyRef reply;
  final String? name;
  final ValueChanged<ReplyRef>? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(reply),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsetsDirectional.only(start: 8),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: scheme.primary, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name != null)
              Text(
                name!,
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              reply.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// The attachment of a message: an inline image, or a tile that downloads and hands the file
/// to the platform; audio plays inline ([_AudioTile]).
class ChatFileView extends StatefulWidget {
  const ChatFileView({super.key, required this.env, required this.file});
  final ChatEnv env;
  final ChatFile file;

  @override
  State<ChatFileView> createState() => _ChatFileViewState();
}

class _ChatFileViewState extends State<ChatFileView> {
  Future<Uint8List>? _image;

  @override
  void initState() {
    super.initState();
    if (widget.file.isImage) _image = widget.env.api.download(widget.file.id);
  }

  Future<void> _open() async {
    final f = widget.file;
    try {
      final bytes = await widget.env.api.download(f.id);
      await widget.env.save(bytes, f.name, f.contentType);
    } on Object {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.chatActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final scheme = Theme.of(context).colorScheme;
    if (f.isImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: GestureDetector(
          onTap: () => unawaited(_open()),
          child: FutureBuilder<Uint8List>(
            future: _image,
            builder: (context, snap) {
              final bytes = snap.data;
              return SizedBox(
                width: _imageWidth,
                height: bytes == null ? 80 : null,
                child: bytes == null
                    ? const Center(child: CircularProgressIndicator())
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.image),
                        ),
                      ),
              );
            },
          ),
        ),
      );
    }
    if (f.isAudio) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _AudioTile(env: widget.env, file: f, onFallback: _open),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => unawaited(_open()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              f.isAudio ? Icons.play_circle_outline : Icons.insert_drive_file,
              color: scheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(f.name, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            const Icon(Icons.download, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Inline audio: downloads on the first tap, then plays and pauses. If playback is not
/// available on the platform the file is handed to the save/share hook instead.
class _AudioTile extends StatefulWidget {
  const _AudioTile({
    required this.env,
    required this.file,
    required this.onFallback,
  });
  final ChatEnv env;
  final ChatFile file;
  final Future<void> Function() onFallback;

  @override
  State<_AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<_AudioTile> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _sub;
  bool _playing = false;
  bool _loading = false;

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    final player = _player;
    if (player != null) {
      await (_playing ? player.pause() : player.resume());
      return;
    }
    setState(() => _loading = true);
    try {
      final bytes = await widget.env.api.download(widget.file.id);
      final p = AudioPlayer();
      _player = p;
      _sub = p.onPlayerStateChanged.listen((st) {
        if (mounted) setState(() => _playing = st == PlayerState.playing);
      });
      await p.play(BytesSource(bytes, mimeType: widget.file.contentType));
    } on Object {
      _player = null;
      await widget.onFallback();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('audio-${widget.file.id}'),
    onTap: _loading ? null : () => unawaited(_toggle()),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _playing
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(widget.file.name, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}
