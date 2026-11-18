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
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Lists the user's keys with status and fingerprint; retire, export, import, compare fingerprint.
/// Warns when a key's fingerprint differs from the one pinned on first sight.
class MyKeysScreen extends StatefulWidget {
  const MyKeysScreen({
    super.key,
    required this.api,
    required this.store,
    this.embedded = false,
  });
  final ApiClient api;
  final KeyStore store;

  /// True when hosted by the app shell, which already provides the AppBar.
  final bool embedded;

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
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final ok = await runKeyAction(context, () async {
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
    if (mounted) {
      setState(() {
        _loading = false;
        _failed = !ok;
      });
    }
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

  void _add() => _push(KeySetupScreen(api: widget.api, store: widget.store));

  List<Widget> get _actions => [
    IconButton(
      tooltip: 'Import key',
      icon: const Icon(Icons.download),
      onPressed: _import,
    ),
    IconButton(
      tooltip: 'Add key for this device',
      icon: const Icon(Icons.add),
      onPressed: _add,
    ),
  ];

  @override
  Widget build(BuildContext context) => KeysPage(
    title: 'My keys',
    embedded: widget.embedded,
    actions: _actions,
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _load, child: _list()),
  );

  Widget _list() {
    if (_keys.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 420,
            child: EmptyState(
              icon: _failed ? Icons.cloud_off : Icons.key_off,
              title: _failed ? 'Could not load your keys' : 'No keys yet',
              message: _failed
                  ? 'Check your connection and pull down to retry.'
                  : 'Create a signing key for this device, or import one from '
                        'another device.',
              action: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _failed ? _load : _add,
                    icon: Icon(_failed ? Icons.refresh : Icons.add),
                    label: Text(_failed ? 'Retry' : 'Create key'),
                  ),
                  if (!_failed)
                    OutlinedButton.icon(
                      onPressed: _import,
                      icon: const Icon(Icons.download),
                      label: const Text('Import key'),
                    ),
                ],
              ),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.embedded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _import,
                        icon: const Icon(Icons.download),
                        label: const Text('Import key'),
                      ),
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text('Add key'),
                      ),
                    ],
                  ),
                ),
              for (final k in _keys) ...[
                _tile(k),
                const SizedBox(height: Tokens.gap),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(UserKeyInfo key) {
    final here = _local?.keyId == key.id;
    final mismatch = _mismatched.contains(key.id);
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                here ? Icons.smartphone : Icons.devices_other,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  key.deviceName,
                  style: text.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusPill(statusLabel(key.status), tone: statusTone(key.status)),
              if (here) const StatusPill('This device', tone: Tone.info),
            ],
          ),
          const SizedBox(height: 12),
          FingerprintPanel(key.fingerprint),
          if (mismatch) ...[
            const SizedBox(height: 12),
            const Notice(
              'Warning: this fingerprint changed since you last saw it. '
              'Report it to the manager unless you changed the key yourself.',
              tone: Tone.error,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 0,
            children: [
              TextButton.icon(
                onPressed: () => showFingerprintDialog(
                  context,
                  key.deviceName,
                  key.fingerprint,
                ),
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Compare fingerprint'),
              ),
              if (mismatch)
                TextButton.icon(
                  onPressed: () async {
                    await widget.store.repin(key.id, key.fingerprint);
                    await _load();
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Accept change'),
                ),
              if (here && key.isActive && !_local!.sealed)
                TextButton.icon(
                  onPressed: () => startKeyExport(context, _transfer),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Export'),
                ),
              if (!key.isRetired)
                TextButton.icon(
                  onPressed: () => _retire(key),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.block),
                  label: const Text('Retire'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
