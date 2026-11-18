import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/keys/key_models.dart';
import 'package:letter_signing/keys/key_ui.dart';
import 'package:letter_signing/keys/keys_api.dart';

/// Manager only: pending keys with the owner's email, device and fingerprint. Approve is enabled
/// only after the manager ticks that they verified the person; reject retires the key.
class KeyApprovalsScreen extends StatefulWidget {
  const KeyApprovalsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<KeyApprovalsScreen> createState() => _KeyApprovalsScreenState();
}

class _KeyApprovalsScreenState extends State<KeyApprovalsScreen> {
  late final KeysApi _api = KeysApi(widget.api);
  List<UserKeyInfo> _pending = const [];
  Map<int, String> _emails = const {};
  Set<String> _verified = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await runKeyAction(context, () async {
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
    if (mounted) setState(() => _loading = false);
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Key approvals')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              children: _pending.isEmpty
                  ? const [
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No keys are waiting for approval.'),
                      ),
                    ]
                  : [for (final k in _pending) _card(k)],
            ),
          ),
  );

  Widget _card(UserKeyInfo key) {
    final verified = _verified.contains(key.id);
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _emails[key.userId] ?? 'User #${key.userId}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Device: ${key.deviceName}'),
            const SizedBox(height: 4),
            FingerprintText(key.fingerprint),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: verified,
              onChanged: (v) => _toggle(key.id, v ?? false),
              title: const Text('I verified this person\'s identity'),
            ),
            Row(
              children: [
                FilledButton(
                  onPressed: verified ? () => _act(key, true) : null,
                  child: const Text('Approve'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _act(key, false),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
