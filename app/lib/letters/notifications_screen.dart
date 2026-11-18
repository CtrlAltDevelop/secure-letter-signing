import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/letters_api.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        TextButton(onPressed: _markRead, child: const Text('Mark all read')),
      ],
    ),
    body: ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.error != null && c.items.isEmpty)
          return Center(child: Text('${c.error}'));
        return RefreshIndicator(
          onRefresh: c.refresh,
          child: c.items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Nothing yet')),
                  ],
                )
              : ListView(
                  children: [
                    for (final n in c.items)
                      ListTile(
                        leading: Icon(
                          n.read
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                        ),
                        title: Text(
                          n.title,
                          style: n.read
                              ? null
                              : const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: n.at == null
                            ? null
                            : Text(n.at!.toLocal().toString().split('.').first),
                        onTap: n.letterId == null || widget.onOpenLetter == null
                            ? null
                            : () => widget.onOpenLetter!(n.letterId!),
                      ),
                  ],
                ),
        );
      },
    ),
  );
}
