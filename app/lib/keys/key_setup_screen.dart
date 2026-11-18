import 'dart:async';

import 'package:flutter/material.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/crypto/identity.dart';
import 'package:letter_signing/keys/key_models.dart';
import 'package:letter_signing/keys/key_store.dart';
import 'package:letter_signing/keys/key_ui.dart';
import 'package:letter_signing/keys/keys_api.dart';
import 'package:letter_signing/keys/password_strength.dart';

const _pollInterval = Duration(seconds: 10);

/// Creates this device's key (protection choice, upload, local save), then shows its status
/// (polling while it waits for manager approval) and fingerprint. Entry widget for the home screen.
class KeySetupScreen extends StatefulWidget {
  const KeySetupScreen({
    super.key,
    required this.api,
    required this.store,
    this.deviceName = '',
    this.onChanged,
  });

  final ApiClient api;
  final KeyStore store;
  final String deviceName;

  /// Called after a key is created or becomes active.
  final VoidCallback? onChanged;

  @override
  State<KeySetupScreen> createState() => _KeySetupScreenState();
}

class _KeySetupScreenState extends State<KeySetupScreen> {
  late final KeysApi _api = KeysApi(widget.api);
  late final _device = TextEditingController(text: widget.deviceName);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  StoredKey? _stored;
  UserKeyInfo? _server;
  KeyProtection _protection = KeyProtection.password;
  bool _biometrics = false;
  bool _loading = true;
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _device.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final stored = await widget.store.load();
    final protection = await widget.store.defaultProtection();
    if (!mounted) return;
    setState(() {
      _stored = stored;
      _protection = protection;
      _biometrics = protection == KeyProtection.sealed;
      _loading = false;
    });
    if (stored != null) await _refresh();
  }

  Future<void> _refresh() async {
    final stored = _stored;
    if (stored == null) return;
    await runKeyAction(context, () async {
      final mine = await _api.mine();
      final match = mine.where((k) => k.id == stored.keyId);
      if (!mounted) return;
      final server = match.isEmpty ? null : match.first;
      setState(() => _server = server);
      _poll?.cancel();
      if (server != null && server.isPending) {
        _poll = Timer(_pollInterval, _refresh);
      } else if (server != null && server.isActive) {
        widget.onChanged?.call();
      }
    });
  }

  bool get _canCreate =>
      !_busy &&
      _device.text.trim().isNotEmpty &&
      (_protection == KeyProtection.sealed ||
          (strongKeyPassword(_password.text) &&
              _password.text == _confirm.text));

  Future<void> _create() async {
    setState(() => _busy = true);
    final ok = await runKeyAction(context, () async {
      final identity = Identity.generate(_device.text.trim());
      final server = await _api.upload(
        deviceName: identity.name,
        signPub: identity.publicFile['sign'] as Map<String, dynamic>,
        encPub: identity.publicFile['enc'] as Map<String, dynamic>,
        fingerprint: identity.fp,
      );
      try {
        final stored = await widget.store.save(
          identity: identity,
          keyId: server.id,
          protection: _protection,
          password: _password.text,
        );
        if (mounted) setState(() => _stored = stored);
      } on Object {
        await _api.retire(server.id); // do not leave an orphan key on the server
        rethrow;
      }
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _password.clear();
      _confirm.clear();
      widget.onChanged?.call();
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your signing key')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: _stored == null ? _form() : _status(),
          ),
  );

  List<Widget> _form() => [
    TextField(
      controller: _device,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(labelText: 'Device name'),
    ),
    const SizedBox(height: 16),
    if (_biometrics)
      SegmentedButton<KeyProtection>(
        segments: const [
          ButtonSegment(
            value: KeyProtection.sealed,
            label: Text('Biometric'),
            icon: Icon(Icons.fingerprint),
          ),
          ButtonSegment(
            value: KeyProtection.password,
            label: Text('Password'),
            icon: Icon(Icons.password),
          ),
        ],
        selected: {_protection},
        onSelectionChanged: (s) => setState(() => _protection = s.first),
      ),
    const SizedBox(height: 8),
    if (_protection == KeyProtection.sealed)
      const Text(
        'The key is sealed to this device and unlocked with your biometrics. '
        'It cannot be exported; a new device needs its own key.',
      )
    else ...[
      const Text(
        'Choose a key password. It cannot be recovered; the key can be moved '
        'to another device only with this password.',
      ),
      TextField(
        controller: _password,
        obscureText: true,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Key password'),
      ),
      TextField(
        controller: _confirm,
        obscureText: true,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Repeat password',
          errorText: _confirm.text.isNotEmpty && _confirm.text != _password.text
              ? 'Passwords differ'
              : null,
        ),
      ),
      const SizedBox(height: 12),
      PasswordStrengthMeter(password: _password.text),
    ],
    const SizedBox(height: 24),
    FilledButton(
      onPressed: _canCreate ? _create : null,
      child: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Create key'),
    ),
  ];

  List<Widget> _status() {
    final stored = _stored!;
    final server = _server;
    final status = server?.status ?? 'pending';
    return [
      ListTile(
        leading: Icon(
          switch (status) {
            'active' => Icons.verified_user,
            'pending' => Icons.hourglass_top,
            _ => Icons.block,
          },
        ),
        title: Text(statusLabel(status)),
        subtitle: Text(
          stored.sealed ? 'Biometric-sealed key' : 'Password-protected key',
        ),
      ),
      const SizedBox(height: 8),
      const Text('Fingerprint'),
      FingerprintText(server?.fingerprint ?? stored.fingerprint, large: true),
      const SizedBox(height: 16),
      if (status == 'pending')
        const Text(
          'The manager must approve this key before you can sign or read letters. '
          'Tell the manager your fingerprint so they can verify it is you.',
        ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh status'),
      ),
    ];
  }
}
