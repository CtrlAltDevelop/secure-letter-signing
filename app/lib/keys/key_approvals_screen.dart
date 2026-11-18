import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/keys/key_models.dart';
import 'package:letter_signing/keys/key_ui.dart';
import 'package:letter_signing/keys/keys_api.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Manager only: pending keys with the owner's email, device and fingerprint. Approve is enabled
/// only after the manager ticks that they verified the person; reject retires the key.
class KeyApprovalsScreen extends StatefulWidget {
  const KeyApprovalsScreen({
    super.key,
    required this.api,
    this.embedded = false,
  });
  final ApiClient api;

  /// True when hosted by the app shell, which already provides the AppBar.
  final bool embedded;

  @override
  State<KeyApprovalsScreen> createState() => _KeyApprovalsScreenState();
}

class _KeyApprovalsScreenState extends State<KeyApprovalsScreen> {
  late final KeysApi _api = KeysApi(widget.api);
  List<UserKeyInfo> _pending = const [];
  Map<int, String> _emails = const {};
  Set<String> _verified = const {};
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final ok = await runKeyAction(context, () async {
      final pending = await _api.pending();
      final users = await widget.api.call('GET', '/manage/users') as List;
      if (!mounted) return;
      setState(() {
        _pending = pending;
        _emails = {
          for (final u in users.cast<Map<String, dynamic>>())
            u['id'] as int: u['email'] as String,
        };
        _verified = _verified.intersection({for (final k in pending) k.id});
      });
    });
    if (mounted) {
      setState(() {
        _loading = false;
        _failed = !ok;
      });
    }
  }

  Future<void> _act(UserKeyInfo key, bool approve) async {
    if (!approve &&
        !await confirm(context, 'Reject key?', 'The key will be retired.')) {
      return;
    }
    if (!mounted) return;
    final ok = await runKeyAction(
      context,
      () => approve ? _api.approve(key.id) : _api.retire(key.id),
    );
    if (ok) await _load();
  }

  void _toggle(String id, bool on) => setState(
    () => _verified = on
        ? {..._verified, id}
        : _verified.where((v) => v != id).toSet(),
  );

  @override
  Widget build(BuildContext context) => KeysPage(
    title: 'Key approvals',
    embedded: widget.embedded,
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _load, child: _list()),
  );

  Widget _list() {
    if (_pending.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 420,
            child: EmptyState(
              icon: _failed ? Icons.cloud_off : Icons.verified_user_outlined,
              title: _failed
                  ? 'Could not load requests'
                  : 'No pending requests',
              message: _failed
                  ? 'Check your connection and pull down to retry.'
                  : 'New device keys that need your approval will show up here.',
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        PageBody(
          child: Column(
            children: [
              for (final k in _pending) ...[
                _card(k),
                const SizedBox(height: Tokens.gap),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(UserKeyInfo key) {
    final verified = _verified.contains(key.id);
    final email = _emails[key.userId] ?? 'User #${key.userId}';
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                foregroundColor: scheme.primary,
                child: Text(email.characters.first.toUpperCase()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      style: text.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Device: ${key.deviceName}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const StatusPill('Pending', tone: Tone.warn),
            ],
          ),
          const SizedBox(height: 12),
          FingerprintPanel(key.fingerprint),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: verified,
            onChanged: (v) => _toggle(key.id, v ?? false),
            title: const Text('I verified this person\'s identity'),
            subtitle: const Text(
              'Compare the fingerprint with theirs in person or by phone.',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: verified ? () => _act(key, true) : null,
                icon: const Icon(Icons.check),
                label: const Text('Approve'),
              ),
              OutlinedButton.icon(
                onPressed: () => _act(key, false),
                style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
