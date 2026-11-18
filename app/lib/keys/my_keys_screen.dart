import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/keys/key_models.dart';
import 'package:letter_signing/keys/key_setup_screen.dart';
import 'package:letter_signing/keys/key_store.dart';
import 'package:letter_signing/keys/key_transfer.dart';
import 'package:letter_signing/keys/key_ui.dart';
import 'package:letter_signing/keys/keys_api.dart';
import 'package:letter_signing/keys/transfer_screens.dart';

/// Lists the user's keys with status and fingerprint; retire, export, import, compare fingerprint.
/// Warns when a key's fingerprint differs from the one pinned on first sight.
class MyKeysScreen extends StatefulWidget {
  const MyKeysScreen({super.key, required this.api, required this.store});
  final ApiClient api;
  final KeyStore store;

  @override
  State<MyKeysScreen> createState() => _MyKeysScreenState();
}

class _MyKeysScreenState extends State<MyKeysScreen> {
  late final KeysApi _api = KeysApi(widget.api);
  late final KeyTransfer _transfer = KeyTransfer(widget.store, _api);
  List<UserKeyInfo> _keys = const [];
  Set<String> _mismatched = const {};
  StoredKey? _local;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await runKeyAction(context, () async {
      final keys = await _api.mine();
      final mismatched = <String>{
        for (final k in keys)
          if (!await widget.store.checkPin(k.id, k.fingerprint)) k.id,
      };
      final local = await widget.store.load();
      if (!mounted) return;
      setState(() {
        _keys = keys;
        _mismatched = mismatched;
        _local = local;
      });
    });
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _retire(UserKeyInfo key) async {
    final ok = await confirm(
      context,
      'Retire key?',
      'The key "${key.deviceName}" can no longer sign or read. Old signatures stay valid.',
    );
    if (!ok || !mounted) return;
    if (await runKeyAction(context, () => _api.retire(key.id))) await _load();
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    await _load();
  }

  Future<void> _import() async {
    if (await startKeyImport(context, _transfer)) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My keys'),
      actions: [
        IconButton(
          tooltip: 'Import key',
          icon: const Icon(Icons.download),
          onPressed: _import,
        ),
        IconButton(
          tooltip: 'Add key for this device',
          icon: const Icon(Icons.add),
          onPressed: () =>
              _push(KeySetupScreen(api: widget.api, store: widget.store)),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(children: [for (final k in _keys) _tile(k)]),
          ),
  );

  Widget _tile(UserKeyInfo key) {
    final here = _local?.keyId == key.id;
    final mismatch = _mismatched.contains(key.id);
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${key.deviceName}${here ? ' (this device)' : ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(statusLabel(key.status)),
            const SizedBox(height: 4),
            FingerprintText(key.fingerprint),
            if (mismatch)
              Text(
                'Warning: this fingerprint changed since you last saw it. '
                'Report it to the manager unless you changed the key yourself.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => showFingerprintDialog(
                    context,
                    key.deviceName,
                    key.fingerprint,
                  ),
                  child: const Text('Compare fingerprint'),
                ),
                if (mismatch)
                  TextButton(
                    onPressed: () async {
                      await widget.store.repin(key.id, key.fingerprint);
                      await _load();
                    },
                    child: const Text('Accept change'),
                  ),
                if (here && key.isActive && !_local!.sealed)
                  TextButton(
                    onPressed: () => startKeyExport(context, _transfer),
                    child: const Text('Export'),
                  ),
                if (!key.isRetired)
                  TextButton(
                    onPressed: () => _retire(key),
                    child: const Text('Retire'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
