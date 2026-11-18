import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/crypto/identity.dart';
import 'package:letter_signing/keys/key_models.dart';
import 'package:letter_signing/keys/key_store.dart';
import 'package:letter_signing/keys/key_ui.dart';
import 'package:letter_signing/keys/keys_api.dart';
import 'package:letter_signing/keys/password_strength.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

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
    this.onSignOut,
  });

  final ApiClient api;
  final KeyStore store;
  final String deviceName;

  /// Called after a key is created or becomes active.
  final VoidCallback? onChanged;

  /// Shown as a 'Sign out' text button (used when this screen is the key gate).
  final VoidCallback? onSignOut;

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
        await _api.retire(
          server.id,
        ); // do not leave an orphan key on the server
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
  Widget build(BuildContext context) {
    final footer = widget.onSignOut == null
        ? null
        : TextButton(
            onPressed: widget.onSignOut,
            child: const Text('Sign out'),
          );
    if (_loading) {
      return AuthScaffold(
        title: 'Your signing key',
        footer: footer,
        children: const [Center(child: CircularProgressIndicator())],
      );
    }
    if (_stored != null) {
      return AuthScaffold(
        title: 'Your signing key',
        subtitle: 'Created on this device',
        footer: footer,
        children: _status(),
      );
    }
    return AuthScaffold(
      title: 'Set up your signing key',
      subtitle:
          'Your signing key proves that letters come from you. It is created '
          'on this device and the private part never leaves it unprotected.',
      footer: footer,
      children: _busy ? _progress() : _form(),
    );
  }

  List<Widget> _progress() => [
    const Center(child: CircularProgressIndicator()),
    Text(
      'Creating your key...',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium,
    ),
    Text(
      'Generating the key and protecting it takes a few seconds. '
      'Please keep this screen open.',
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  ];

  List<Widget> _form() => [
    TextField(
      controller: _device,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Device name',
        prefixIcon: Icon(Icons.devices),
      ),
    ),
    if (_biometrics) ...[
      _ChoiceCard(
        icon: Icons.fingerprint,
        title: 'Biometric',
        text:
            'Sealed to this device and unlocked with your fingerprint or face. '
            'It cannot be moved: another device needs its own key.',
        selected: _protection == KeyProtection.sealed,
        onTap: () => setState(() => _protection = KeyProtection.sealed),
      ),
      _ChoiceCard(
        icon: Icons.password,
        title: 'Strong password',
        text:
            'Protected by a password only you know. It can be moved to '
            'another device by QR code or file.',
        selected: _protection == KeyProtection.password,
        onTap: () => setState(() => _protection = KeyProtection.password),
      ),
    ] else
      Text(
        'The key is protected by a password only you know. It can be moved to '
        'another device by QR code or file.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    if (_protection == KeyProtection.password) ..._passwordFields(),
    FilledButton(
      onPressed: _canCreate ? _create : null,
      child: const Text('Create key'),
    ),
  ];

  List<Widget> _passwordFields() => [
    PasswordField(
      controller: _password,
      label: 'Key password',
      onChanged: (_) => setState(() {}),
    ),
    PasswordStrengthMeter(password: _password.text),
    PasswordField(
      controller: _confirm,
      label: 'Repeat password',
      onChanged: (_) => setState(() {}),
      errorText: _confirm.text.isNotEmpty && _confirm.text != _password.text
          ? 'Passwords differ'
          : null,
    ),
    const Notice(
      'The password cannot be recovered. If you forget it, the key must be '
      'replaced.',
      tone: Tone.warn,
    ),
  ];

  List<Widget> _status() {
    final stored = _stored!;
    final status = _server?.status ?? 'pending';
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return [
      Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusPill(statusLabel(status), tone: statusTone(status)),
          Text(
            stored.sealed ? 'Biometric-sealed key' : 'Password-protected key',
            style: text.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
      Text('Fingerprint', style: text.labelLarge),
      FingerprintPanel(_server?.fingerprint ?? stored.fingerprint, large: true),
      if (status == 'active')
        const Notice(
          'Your key is active. You can sign and read letters.',
          tone: Tone.ok,
        )
      else if (status == 'pending')
        const Notice(
          'The manager must approve this key before you can sign or read '
          'letters. Tell the manager your fingerprint so they can verify it '
          'is you. This page updates by itself.',
          tone: Tone.warn,
        )
      else
        const Notice('This key was retired.', tone: Tone.error),
      OutlinedButton.icon(
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh status'),
      ),
    ];
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusSmall),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusSmall),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? scheme.primary : null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
