import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/screens/auth_screens.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/widgets.dart';

IconData platformIcon(String platform) => switch (platform.toLowerCase()) {
  'android' || 'ios' || 'iphone' => Icons.smartphone,
  'macos' || 'windows' || 'linux' => Icons.laptop_mac,
  _ => Icons.devices_other,
};

class SessionsTab extends StatefulWidget {
  const SessionsTab({super.key, required this.auth});
  final AuthController auth;

  @override
  State<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  late Future<List<Map<String, dynamic>>> _sessions = _load();

  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(
        await widget.auth.api.call('GET', '/me/sessions') as List,
      );

  void _reload() {
    setState(() {
      _sessions = _load();
    });
  }

  Future<void> _revoke(Map<String, dynamic> s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out this device?'),
        content: Text('${_nameOf(s)} will need to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await runGuarded(
      context,
      () => widget.auth.api.call('POST', '/me/sessions/${s['id']}/revoke'),
    );
    if (ok && mounted) _reload();
  }

  String _nameOf(Map<String, dynamic> s) {
    final name = '${s['device_name'] ?? ''}';
    return name.isEmpty ? '${s['platform'] ?? 'Unknown device'}' : name;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _sessions,
      builder: (context, snap) {
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load devices',
            message: '${snap.error}',
            action: OutlinedButton(
              onPressed: _reload,
              child: const Text('Retry'),
            ),
          );
        }
        final rows = snap.data;
        if (rows == null)
          return const Center(child: CircularProgressIndicator());
        if (rows.isEmpty) {
          return const EmptyState(
            icon: Icons.devices_outlined,
            title: 'No signed-in devices',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              PageBody(
                child: Column(
                  children: [
                    for (final s in rows) ...[
                      _SessionCard(
                        name: _nameOf(s),
                        platform: '${s['platform'] ?? ''}',
                        ip: '${s['ip'] ?? ''}',
                        lastActive: relativeTime(s['last_active']),
                        current: s['current'] == true,
                        onRevoke: () => _revoke(s),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.name,
    required this.platform,
    required this.ip,
    required this.lastActive,
    required this.current,
    required this.onRevoke,
  });
  final String name;
  final String platform;
  final String ip;
  final String lastActive;
  final bool current;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          Icon(platformIcon(platform), size: 30, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(name, style: text.titleSmall),
                    if (current) const StatusPill('This device', tone: Tone.ok),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [if (ip.isNotEmpty) ip, 'Active $lastActive'].join('  ·  '),
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!current)
            IconButton(
              tooltip: 'Sign out this device',
              icon: const Icon(Icons.logout),
              onPressed: onRevoke,
            ),
        ],
      ),
    );
  }
}
