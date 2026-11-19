import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/screens/ui_bits.dart';

/// Title of a conversation: the other person for a DM, else its name.
String conversationTitle(Conversation c) =>
    c.isDm ? (c.otherUser?.displayName ?? c.name) : c.name;

/// One row of the list: avatar, title, preview, time, unread badge, pin and mute marks.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onLongPress,
    this.onJoin,
  });

  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Shown for public conversations I have not joined.
  final VoidCallback? onJoin;

  Widget _avatar(BuildContext context) {
    final c = conversation;
    if (c.isDm) {
      final u = c.otherUser;
      return UserAvatar(fullName: u?.fullName ?? c.name, email: u?.email ?? '');
    }
    return CircleAvatar(
      child: Icon(
        c.isChannel ? Icons.campaign_outlined : Icons.groups_outlined,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final c = conversation;
    final unread = c.unread > 0;
    final subtitle = c.isMember
        ? c.lastPreview
        : l.chatMembersCount(toPersianDigits(c.memberCount));
    return ListTile(
      leading: _avatar(context),
      title: Row(
        children: [
          Flexible(
            child: Text(
              conversationTitle(c),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: unread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (c.pinned)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Icon(Icons.push_pin, size: 14, color: scheme.outline),
            ),
          if (c.muted)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Icon(Icons.volume_off, size: 14, color: scheme.outline),
            ),
        ],
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: !c.isMember && onJoin != null
          ? FilledButton.tonal(onPressed: onJoin, child: Text(l.chatJoin))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (c.lastMessageAt != null)
                  Text(
                    formatRelative(c.lastMessageAt!),
                    style: TextStyle(fontSize: 11, color: scheme.outline),
                  ),
                if (unread)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Badge(
                      backgroundColor: c.muted ? scheme.outline : null,
                      label: Text(
                        toPersianDigits(c.unread),
                        semanticsLabel: '${c.unread}',
                      ),
                    ),
                  ),
              ],
            ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
