import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/letters_api.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// In-app notifications: GET /me/notifications plus live pushes (the fallback when SMTP is not configured).
class NotificationsController extends ChangeNotifier {
  NotificationsController({required this.api, required this.live}) {
    _sub = live.events.listen(_onEvent);
  }

  final LettersApi api;
  final LiveService live;
  late final StreamSubscription<LiveEvent> _sub;
  List<AppNotification> _items = const [];
  Object? error;

  List<AppNotification> get items => _items;
  int get unread => _items.where((n) => !n.read).length;

  Future<void> refresh() async {
    try {
      _items = (await api.notifications()).reversed.toList();
      error = null;
    } on Object catch (e) {
      error = e;
    }
    notifyListeners();
  }

  void _onEvent(LiveEvent e) {
    final n = e.toNotification();
    if (n == null || _items.any((x) => x.id == n.id)) return;
    _items = [n, ..._items];
    notifyListeners();
  }

  Future<void> markAllRead() async {
    await api.markNotificationsRead();
    _items = [for (final n in _items) n.markRead()];
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}

/// Bell icon with an unread badge; opens [NotificationsScreen].
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.env, this.onOpenLetter});
  final LettersEnv env;
  final void Function(String letterId)? onOpenLetter;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: env.notifications,
    builder: (context, _) => IconButton(
      tooltip: 'Notifications',
      icon: Badge(
        isLabelVisible: env.notifications.unread > 0,
        label: Text('${env.notifications.unread}'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              NotificationsScreen(env: env, onOpenLetter: onOpenLetter),
        ),
      ),
    ),
  );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.env, this.onOpenLetter});
  final LettersEnv env;
  final void Function(String letterId)? onOpenLetter;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationsController get c => widget.env.notifications;

  @override
  void initState() {
    super.initState();
    unawaited(c.refresh());
  }

  Future<void> _markRead() async {
    try {
      await c.markAllRead();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  static String _group(DateTime? at) {
    if (at == null) return 'Earlier';
    final now = DateTime.now();
    final d = at.toLocal();
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return 'Earlier';
  }

  Widget _list() {
    final groups = <String, List<AppNotification>>{};
    for (final n in c.items) {
      groups.putIfAbsent(_group(n.at), () => []).add(n);
    }
    return ListView(
      children: [
        for (final g in groups.entries) ...[
          SectionHeader(g.key),
          for (final n in g.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _NotificationTile(
                n: n,
                onTap: n.letterId == null || widget.onOpenLetter == null
                    ? null
                    : () => widget.onOpenLetter!(n.letterId!),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        TextButton.icon(
          onPressed: _markRead,
          icon: const Icon(Icons.done_all),
          label: const Text('Mark all read'),
        ),
      ],
    ),
    body: PageBody(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (c.error != null && c.items.isEmpty) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load notifications',
              message: '${c.error}',
              action: OutlinedButton.icon(
                onPressed: c.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: c.refresh,
            child: c.items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 48),
                      EmptyState(
                        icon: Icons.notifications_none,
                        title: 'Nothing yet',
                        message: 'You will be told when a letter needs you.',
                      ),
                    ],
                  )
                : _list(),
          );
        },
      ),
    ),
  );
}

(IconData, Color?) _kindStyle(String kind) {
  if (kind.contains('reject')) return (Icons.cancel_outlined, Tokens.error);
  if (kind.contains('approv') || kind.contains('publish')) {
    return (Icons.check_circle_outline, Tokens.ok);
  }
  if (kind.contains('sign') || kind.contains('turn')) {
    return (Icons.draw_outlined, Tokens.warn);
  }
  if (kind.contains('key')) return (Icons.vpn_key_outlined, null);
  return (Icons.mail_outline, null);
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.n, this.onTap});
  final AppNotification n;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, tint) = _kindStyle(n.kind);
    final color = tint ?? scheme.primary;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.read ? FontWeight.w400 : FontWeight.w700,
                  ),
                ),
                if (n.at != null)
                  Text(
                    fmtDateTime(n.at!),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
          if (!n.read)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: scheme.secondary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
