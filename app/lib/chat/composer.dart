import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/chat_sheets.dart';
import 'package:letter_signing/chat/chat_text.dart';
import 'package:letter_signing/chat/conversation_controller.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome;

/// The message box: reply banner, a small tool row (attach, paste, @mention, bold, italic,
/// voice in DMs when a recorder hook is set) and the text field with the send button.
class Composer extends StatefulWidget {
  const Composer({super.key, required this.env, required this.controller});
  final ChatEnv env;
  final ConversationController controller;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _text = TextEditingController();
  final _mentioned = <int, String>{};
  bool _sending = false;

  ConversationController get c => widget.controller;
  ChatEnv get env => widget.env;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _report(ActionOutcome out) {
    if (out == ActionOutcome.ok || !mounted) return;
    final l = AppLocalizations.of(context);
    final text = out == ActionOutcome.forbidden
        ? l.chatForbidden
        : l.chatSendFailed;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _guard(Future<ActionOutcome> Function() run) async {
    if (_sending) return;
    setState(() => _sending = true);
    final out = await run();
    if (!mounted) return;
    setState(() => _sending = false);
    _report(out);
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final ids = mentionedIds(text, _mentioned);
    await _guard(() async {
      final out = await c.send(text: text, mentions: ids);
      if (out == ActionOutcome.ok) {
        _text.clear();
        _mentioned.clear();
      }
      return out;
    });
  }

  Future<void> _sendPicked(PickedFile f, {String? kind}) async {
    final caption = _text.text.trim();
    await _guard(() async {
      final out = await c.sendFile(
        name: f.name,
        bytes: f.bytes,
        contentType: f.contentType,
        text: caption,
        kind: kind,
      );
      if (out == ActionOutcome.ok) _text.clear();
      return out;
    });
  }

  Future<void> _attach() async {
    final f = await env.pickFile();
    if (f != null) await _sendPicked(f);
  }

  Future<void> _record() async {
    final f = await env.recordVoice?.call();
    if (f != null) await _sendPicked(f, kind: 'voice');
  }

  void _insert(String s) {
    final sel = _text.selection;
    final at = sel.isValid ? sel.start : _text.text.length;
    final end = sel.isValid ? sel.end : at;
    _text.value = TextEditingValue(
      text: _text.text.replaceRange(at, end, s),
      selection: TextSelection.collapsed(offset: at + s.length),
    );
  }

  Future<void> _paste() async {
    final img = await env.readClipboardImage?.call();
    if (img != null) return _sendPicked(img);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text ?? '';
    if (t.isNotEmpty) return _insert(t);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).chatPasteEmpty)),
    );
  }

  /// Wraps the selection in [mark] (or inserts an empty pair with the caret between).
  void _wrap(String mark) {
    final sel = _text.selection;
    final at = sel.isValid ? sel.start : _text.text.length;
    final end = sel.isValid ? sel.end : at;
    final inner = _text.text.substring(at, end);
    _text.value = TextEditingValue(
      text: _text.text.replaceRange(at, end, '$mark$inner$mark'),
      selection: TextSelection.collapsed(
        offset: inner.isEmpty ? at + mark.length : at + inner.length + 2,
      ),
    );
  }

  Future<List<UserRef>> _candidates() async {
    final members = c.conversation?.members;
    final all = members == null
        ? await env.directory()
        : [for (final m in members) m.user];
    return [
      for (final u in all)
        if (u.id != env.userId) u,
    ];
  }

  Future<void> _mention({bool typed = false}) async {
    final u = await showUserPickSheet(
      context,
      title: AppLocalizations.of(context).chatMentionSearch,
      load: _candidates,
    );
    if (u == null || !mounted) return;
    if (typed) _dropTypedAt();
    _mentioned[u.id] = u.displayName;
    _insert('@${u.displayName} ');
  }

  /// Removes the `@` the user just typed (the picker re-inserts it with the name).
  void _dropTypedAt() {
    final pos = _text.selection.baseOffset;
    if (pos > 0 && _text.text[pos - 1] == '@') {
      _text.value = TextEditingValue(
        text: _text.text.replaceRange(pos - 1, pos, ''),
        selection: TextSelection.collapsed(offset: pos - 1),
      );
    }
  }

  void _onChanged(String v) {
    final pos = _text.selection.baseOffset;
    if (pos < 1 || pos > v.length || v[pos - 1] != '@') return;
    if (pos == 1 || v[pos - 2].trim().isEmpty) {
      unawaited(_mention(typed: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final conv = c.conversation;
        if (conv == null || !conv.isMember) return const SizedBox.shrink();
        if (conv.archived || !c.canPost) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              conv.archived ? l.chatArchivedNote : l.chatReadOnly,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (c.replyTo != null) _replyBanner(context, l),
              _tools(l, conv.isDm),
              _field(l),
            ],
          ),
        );
      },
    );
  }

  Widget _replyBanner(BuildContext context, AppLocalizations l) {
    final m = c.replyTo!;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.reply),
      title: Text(l.chatReplyingTo(m.author.displayName)),
      subtitle: Text(
        m.deleted ? l.chatDeleted : m.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: l.chatCancelReply,
        icon: const Icon(Icons.close),
        onPressed: () => c.setReplyTo(null),
      ),
    );
  }

  Widget _tools(AppLocalizations l, bool isDm) {
    Widget btn(IconData icon, String tip, VoidCallback onTap) => IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 20),
      onPressed: _sending ? null : onTap,
    );
    return Row(
      children: [
        btn(Icons.attach_file, l.chatAttach, () => unawaited(_attach())),
        btn(Icons.content_paste, l.chatPaste, () => unawaited(_paste())),
        btn(Icons.alternate_email, l.chatMention, () => unawaited(_mention())),
        btn(Icons.format_bold, 'B', () => _wrap('*')),
        btn(Icons.format_italic, 'I', () => _wrap('_')),
        if (isDm && env.recordVoice != null)
          btn(Icons.mic, l.chatVoice, () => unawaited(_record())),
      ],
    );
  }

  Widget _field(AppLocalizations l) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _text,
            minLines: 1,
            maxLines: 5,
            maxLength: 4000,
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(hintText: l.chatMessageHint),
            onChanged: _onChanged,
          ),
        ),
        const SizedBox(width: 4),
        IconButton.filled(
          tooltip: l.chatSend,
          icon: const Icon(Icons.send),
          onPressed: _sending ? null : () => unawaited(_send()),
        ),
      ],
    ),
  );
}
