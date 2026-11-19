import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/models.dart' show AppNotification;
import 'package:letter_signing/prefs/models.dart';
import 'package:letter_signing/prefs/prefs_api.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/module_label.dart';
import 'package:letter_signing/workspace/open_target.dart';

/// Notification history (`GET /me/notifications`) with unread marks and "mark all read", plus
/// the mentions inbox (`GET /me/mentions`) as a second filter.
class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({
    super.key,
    required this.api,
    required this.open,
  });

  final PrefsApi api;
  final OpenFn open;

  @override
  State<NotificationHistoryScreen> createState() => _State();
}

enum _Filter { all, unread, mentions }

class _State extends State<NotificationHistoryScreen> {
  List<AppNotification> _items = const [];
  List<MentionItem> _mentions = const [];
  _Filter _filter = _Filter.all;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        widget.api.notifications(),
        widget.api.mentions().catchError((Object _) => <MentionItem>[]),
      ]);
      _items = r[0] as List<AppNotification>;
      _mentions = r[1] as List<MentionItem>;
      _error = null;
    } on Object catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markAll() async {
    try {
      await widget.api.markAllRead();
      if (mounted) {
        setState(() => _items = [for (final n in _items) n.markRead()]);
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).prefsFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notificationsTitle),
        actions: [
          IconButton(
            key: const ValueKey('mark-all-read'),
            tooltip: l.notificationsMarkAll,
            icon: const Icon(Icons.done_all),
            onPressed: () => unawaited(_markAll()),
          ),
        ],
      ),
      body: PageBody(child: _body(context, l)),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.notificationsLoadFailed,
        action: OutlinedButton(
          onPressed: () {
            setState(() => _loading = true);
            unawaited(_load());
          },
          child: Text(l.commonRetry),
        ),
      );
    }
    return Column(
      children: [
        SegmentedButton<_Filter>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: _Filter.all, label: Text(l.tasksFilterAll)),
            ButtonSegment(
              value: _Filter.unread,
              label: Text(l.notificationsUnread),
            ),
            ButtonSegment(
              value: _Filter.mentions,
              label: Text(l.notificationsMentions),
            ),
          ],
          selected: {_filter},
          onSelectionChanged: (s) => setState(() => _filter = s.first),
        ),
        Expanded(child: _list(context, l)),
      ],
    );
  }

  Widget _list(BuildContext context, AppLocalizations l) {
    if (_filter == _Filter.mentions) {
      if (_mentions.isEmpty) {
        return EmptyState(
          icon: Icons.alternate_email,
          title: l.notificationsNoMentions,
        );
      }
      return ListView(
        children: [for (final m in _mentions) _mention(context, m, l)],
      );
    }
    final shown = [
      for (final n in _items)
        if (_filter == _Filter.all || !n.read) n,
    ];
    if (shown.isEmpty) {
      return EmptyState(
        icon: Icons.notifications_none,
        title: l.notificationsEmpty,
      );
    }
    return ListView(
      children: [
        for (final n in shown)
          ListTile(
            key: ValueKey('notif-${n.id}'),
            leading: Icon(
              n.read ? Icons.notifications_none : Icons.notifications_active,
              color: n.read ? null : Theme.of(context).colorScheme.secondary,
            ),
            title: Text(
              n.title,
              style: TextStyle(
                fontWeight: n.read ? FontWeight.w400 : FontWeight.w700,
              ),
            ),
            subtitle: n.at == null ? null : Text(formatJalaliDateTime(n.at!)),
            trailing: n.read
                ? null
                : Icon(
                    Icons.circle,
                    size: 10,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            onTap: n.letterId == null
                ? null
                : () => unawaited(
                    widget.open(
                      context,
                      OpenTarget(module: 'letters', id: n.letterId!),
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _mention(BuildContext context, MentionItem m, AppLocalizations l) =>
      ListTile(
        key: ValueKey('mention-${m.commentId}'),
        leading: const Icon(Icons.alternate_email),
        title: Text('${m.author}: ${m.excerpt}', maxLines: 2),
        subtitle: Text('${moduleLabel(l, m.module)} - ${m.title}'),
        onTap: () => unawaited(
          widget.open(
            context,
            OpenTarget(
              module: m.module,
              kind: m.objectId.isEmpty ? 'subject' : m.kind,
              id: m.objectId.isEmpty ? m.subjectId : m.objectId,
              subjectId: m.subjectId,
            ),
          ),
        ),
      );
}
