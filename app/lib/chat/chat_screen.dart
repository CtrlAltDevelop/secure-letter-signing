import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/chat_sheets.dart';
import 'package:letter_signing/chat/conversation_screen.dart';
import 'package:letter_signing/chat/conversation_tile.dart';
import 'package:letter_signing/chat/conversations_controller.dart';
import 'package:letter_signing/chat/create_conversation_screen.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show SkeletonList;
import 'package:letter_signing/theme/widgets.dart';

/// The Chat module: my conversations (pinned first) or the public ones to join, a search box,
/// a kind filter and a "new" menu (direct message, group, channel).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.env});
  final ChatEnv env;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ConversationsController _c = ConversationsController(
    api: widget.env.api,
    live: widget.env.live,
    userId: widget.env.userId,
  );
  final _search = TextEditingController();

  ChatEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    unawaited(_c.load());
  }

  @override
  void dispose() {
    _c.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Conversation c) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ConversationScreen(env: env, conversationId: c.id, initial: c),
      ),
    );
    if (mounted) unawaited(_c.load());
  }

  Future<void> _newDm() async {
    final l = AppLocalizations.of(context);
    final u = await showUserPickSheet(
      context,
      title: l.chatDmPickTitle,
      load: () async => [
        for (final x in await env.directory())
          if (x.id != env.userId) x,
      ],
    );
    if (u == null || !mounted) return;
    try {
      await _open(await env.api.startDm(u.id));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.chatActionFailed)));
    }
  }

  Future<void> _create(String kind) async {
    final made = await Navigator.of(context).push<Conversation>(
      MaterialPageRoute(
        builder: (_) => CreateConversationScreen(env: env, kind: kind),
      ),
    );
    if (made != null && mounted) await _open(made);
  }

  Future<void> _newMenu() async {
    final l = AppLocalizations.of(context);
    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l.chatNewDm),
              onTap: () => Navigator.pop(ctx, ConvKind.dm),
            ),
            if (env.canCreateGroup) ...[
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(l.chatNewGroup),
                onTap: () => Navigator.pop(ctx, ConvKind.group),
              ),
              ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: Text(l.chatNewChannel),
                onTap: () => Navigator.pop(ctx, ConvKind.channel),
              ),
            ],
          ],
        ),
      ),
    );
    if (pick == null) return;
    await (pick == ConvKind.dm ? _newDm() : _create(pick));
  }

  Future<void> _rowMenu(Conversation c) async {
    final l = AppLocalizations.of(context);
    if (!c.isMember) return;
    final act = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(c.pinned ? l.chatUnpinConv : l.chatPinConv),
              onTap: () => Navigator.pop(ctx, 'pin'),
            ),
            ListTile(
              leading: Icon(
                c.muted ? Icons.volume_up_outlined : Icons.volume_off_outlined,
              ),
              title: Text(c.muted ? l.chatUnmute : l.chatMute),
              onTap: () => Navigator.pop(ctx, 'mute'),
            ),
          ],
        ),
      ),
    );
    if (act == 'pin') await _c.pin(c, pinned: !c.pinned);
    if (act == 'mute') await _c.mute(c, muted: !c.muted);
  }

  Widget _toolbar(AppLocalizations l) {
    final f = _c.filter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l.chatSearchHint,
          ),
          onSubmitted: (v) => unawaited(_c.setFilter(f.copyWith(q: v.trim()))),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l.chatTabMine)),
            ButtonSegment(value: true, label: Text(l.chatTabPublic)),
          ],
          selected: {f.publicOnly},
          onSelectionChanged: (s) =>
              unawaited(_c.setFilter(f.copyWith(publicOnly: s.first))),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final (kind, label) in [
              (ConvKind.group, l.chatKindGroup),
              (ConvKind.channel, l.chatKindChannel),
              (ConvKind.dm, l.chatKindDm),
            ])
              if (!(f.publicOnly && kind == ConvKind.dm))
                FilterChip(
                  label: Text(label),
                  selected: f.kind == kind,
                  onSelected: (on) => unawaited(
                    _c.setFilter(
                      on ? f.copyWith(kind: kind) : f.copyWith(clearKind: true),
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  Widget _list(AppLocalizations l) {
    if (_c.loading) return const SkeletonList(count: 5);
    if (_c.error != null && _c.items.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.chatLoadFailed,
        message: '${_c.error}',
        action: OutlinedButton.icon(
          onPressed: () => unawaited(_c.load()),
          icon: const Icon(Icons.refresh),
          label: Text(l.commonRetry),
        ),
      );
    }
    if (_c.items.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline,
        title: _c.filter.publicOnly ? l.chatEmptyPublic : l.chatEmptyTitle,
        message: _c.filter.publicOnly ? null : l.chatEmptyMessage,
      );
    }
    return RefreshIndicator(
      onRefresh: _c.load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final c in _c.items)
            ConversationTile(
              key: ValueKey(c.id),
              conversation: c,
              onTap: () => unawaited(_open(c)),
              onLongPress: () => unawaited(_rowMenu(c)),
              onJoin: c.canJoin ? () => unawaited(_join(c)) : null,
            ),
        ],
      ),
    );
  }

  Future<void> _join(Conversation c) async {
    await _c.join(c);
    if (mounted) await _open(c);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => unawaited(_newMenu()),
          icon: const Icon(Icons.add_comment_outlined),
          label: Text(l.chatNew),
        ),
        body: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolbar(l),
              const SizedBox(height: 8),
              Expanded(child: _list(l)),
            ],
          ),
        ),
      ),
    );
  }
}
