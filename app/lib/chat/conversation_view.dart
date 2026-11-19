import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/composer.dart';
import 'package:letter_signing/chat/conversation_controller.dart';
import 'package:letter_signing/chat/message_actions.dart';
import 'package:letter_signing/chat/message_bubble.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show SkeletonList;
import 'package:letter_signing/theme/widgets.dart';

const _edgeTrigger = 240.0;

/// The body of an open conversation: pins bar, messages (newest at the bottom, older pages
/// load when scrolling up), join banner and composer. Used by the conversation screen and by
/// the project / customer chat tabs.
class ConversationView extends StatefulWidget {
  const ConversationView({
    super.key,
    required this.env,
    required this.controller,
  });
  final ChatEnv env;
  final ConversationController controller;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final _scroll = ScrollController();

  ConversationController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    // The list is reversed: the "top" (older) is the max extent.
    if (p.maxScrollExtent - p.pixels < _edgeTrigger) unawaited(c.loadOlder());
    if (p.pixels < _edgeTrigger && !c.atLatest) unawaited(c.loadNewer());
  }

  int _seenJumps = 0;

  /// After a jump the window's first message must be in view: scroll to the older end.
  void _showOldestEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  String? _nameOf(int id) {
    if (id == widget.env.userId) return widget.env.userName;
    for (final m in c.conversation?.members ?? const <ChatMember>[]) {
      if (m.user.id == id) return m.user.displayName;
    }
    for (final m in c.messages) {
      if (m.author.id == id) return m.author.displayName;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final conv = c.conversation;
        if (_seenJumps != c.windowJumps) {
          _seenJumps = c.windowJumps;
          _showOldestEnd();
        }
        if (c.loading && conv == null) return const SkeletonList(count: 4);
        if (conv == null) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l.chatLoadFailed,
            message: '${c.error}',
            action: OutlinedButton.icon(
              onPressed: () => unawaited(c.load()),
              icon: const Icon(Icons.refresh),
              label: Text(l.commonRetry),
            ),
          );
        }
        return Column(
          children: [
            if (c.pins.isNotEmpty) _pinsBar(context, l),
            Expanded(child: _messages(context, conv, l)),
            if (!c.atLatest) _latestButton(l),
            if (!conv.isMember)
              _joinBar(conv, l)
            else
              Composer(env: widget.env, controller: c),
          ],
        );
      },
    );
  }

  Widget _latestButton(AppLocalizations l) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: TextButton.icon(
      onPressed: () => unawaited(c.jumpToLatest()),
      icon: const Icon(Icons.arrow_downward, size: 18),
      label: Text(l.chatJumpLatest),
    ),
  );

  Widget _joinBar(Conversation conv, AppLocalizations l) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.chatNotMember),
          const SizedBox(height: 8),
          if (conv.canJoin)
            FilledButton(
              onPressed: () => unawaited(c.join()),
              child: Text(l.chatJoin),
            ),
        ],
      ),
    ),
  );

  Widget _pinsBar(BuildContext context, AppLocalizations l) {
    final scheme = Theme.of(context).colorScheme;
    final latest = c.pins.first;
    return Material(
      color: scheme.secondaryContainer,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.push_pin, size: 18),
        title: Text(
          latest.text.isEmpty ? (latest.file?.name ?? '') : latest.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: c.pins.length > 1
            ? Text(l.chatPinsBar(toPersianDigits(c.pins.length)))
            : null,
        onTap: () => unawaited(_showPins(context, l)),
      ),
    );
  }

  Future<void> _showPins(BuildContext context, AppLocalizations l) async {
    final picked = await showModalBottomSheet<ChatMessage>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final m in c.pins)
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: Text(
                  m.text.isEmpty ? (m.file?.name ?? '') : m.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(m.author.displayName),
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await c.jumpToSeq(picked.seq);
  }

  Widget _messages(
    BuildContext context,
    Conversation conv,
    AppLocalizations l,
  ) {
    if (!conv.isMember) return const SizedBox.shrink();
    final rows = c.messages;
    if (rows.isEmpty) return const SizedBox.shrink();
    final isDm = conv.isDm;
    final items = <Widget>[];
    DateTime? day;
    for (final (i, m) in rows.indexed) {
      final at = m.createdAt?.toLocal();
      if (at != null && (day == null || !_sameDay(day, at))) {
        items.add(_dayChip(context, at));
        day = at;
      }
      final prev = i > 0 ? rows[i - 1] : null;
      items.add(
        Padding(
          key: ValueKey('m${m.id}'),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: MessageBubble(
            env: widget.env,
            message: m,
            mine: m.author.id == widget.env.userId,
            showAuthor: !isDm && prev?.author.id != m.author.id,
            nameOf: _nameOf,
            seenByOther:
                isDm &&
                m.author.id == widget.env.userId &&
                conv.otherUser != null &&
                c.readSeqOf(conv.otherUser!.id) >= m.seq,
            onReplyTap: (r) => unawaited(c.jumpToSeq(r.seq)),
            onActions: () => unawaited(
              showMessageActions(
                context,
                env: widget.env,
                controller: c,
                message: m,
              ),
            ),
          ),
        ),
      );
    }
    final reversed = items.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.all(8),
      itemCount: reversed.length + (c.hasOlder ? 1 : 0),
      itemBuilder: (_, i) => i == reversed.length
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          : reversed[i],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dayChip(BuildContext context, DateTime at) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        formatJalaliLong(at),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    ),
  );
}
