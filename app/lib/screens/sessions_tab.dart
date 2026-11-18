import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/screens/auth_screens.dart';
import 'package:letter_signing/screens/biometric_enrol.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/widgets.dart';

class SessionsTab extends StatefulWidget {
  const SessionsTab({super.key, required this.auth});
  final AuthController auth;

  @override
  State<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  late Future<List<SessionInfo>> _sessions = _load();

  Future<List<SessionInfo>> _load() async => [
    for (final e in await widget.auth.api.call('GET', '/me/sessions') as List)
      SessionInfo.fromJson(Map<String, dynamic>.from(e as Map)),
  ];

  void _reload() {
    setState(() {
      _sessions = _load();
    });
  }

  Future<void> _revoke(SessionInfo s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out this device?'),
        content: Text('${s.displayName} will need to sign in again.'),
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
      () => widget.auth.api.call('POST', '/me/sessions/${s.id}/revoke'),
    );
    if (ok && mounted) _reload();
  }

  Future<void> _enableBiometric() async {
    final done = await showBiometricEnrolDialog(
      context,
      enroll: widget.auth.enrollBiometric,
    );
    if (done && mounted) _reload();
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
        if (rows == null) {
          return const Center(child: CircularProgressIndicator());
        }
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
                        name: s.displayName,
                        platform: s.platform,
                        ip: s.ip,
                        lastActive: relativeTime(s.lastActive),
                        current: s.current,
                        biometric: s.biometric,
                        onRevoke: () => _revoke(s),
                        onEnableBiometric:
                            s.current &&
                                !s.biometric &&
                                widget.auth.biometricAvailable
                            ? _enableBiometric
                            : null,
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
    required this.biometric,
    required this.onRevoke,
    this.onEnableBiometric,
  });
  final String name;
  final String platform;
  final String ip;
  final String lastActive;
  final bool current;
  final bool biometric;
  final VoidCallback onRevoke;
  final VoidCallback? onEnableBiometric;

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
                    if (biometric)
                      const StatusPill('Biometric', tone: Tone.info),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [if (ip.isNotEmpty) ip, 'Active $lastActive'].join('  ·  '),
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (onEnableBiometric != null)
                  TextButton.icon(
                    onPressed: onEnableBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Enable fingerprint / face'),
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
