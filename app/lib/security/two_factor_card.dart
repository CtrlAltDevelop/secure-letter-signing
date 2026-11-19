import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/security/security_api.dart';
import 'package:letter_signing/security/security_models.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/screens/ui_bits.dart';

/// Profile > Security: turn two-step login on or off and manage recovery codes.
class TwoFactorCard extends StatefulWidget {
  const TwoFactorCard({super.key, required this.api, required this.auth});
  final SecurityApi api;
  final AuthController auth;

  @override
  State<TwoFactorCard> createState() => _TwoFactorCardState();
}

class _TwoFactorCardState extends State<TwoFactorCard> {
  TwoFactorStatus? _status;
  TwoFactorSetup? _setup;
  Object? _error;
  bool _busy = false;
  final _code = TextEditingController();
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await widget.api.status();
      if (mounted) {
        setState(() {
          _status = s;
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } on Exception {
      if (mounted) _snack(AppLocalizations.of(context).secNoConnection);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _start() => _guard(() async {
    final setup = await widget.api.startSetup();
    if (mounted) setState(() => _setup = setup);
  });

  Future<void> _confirm() async {
    final l = AppLocalizations.of(context);
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _codeError = l.secCodeInvalid);
      return;
    }
    setState(() => _codeError = null);
    List<String>? codes;
    await _guard(() async {
      codes = await widget.api.confirm(_code.text.trim());
    });
    final shown = codes;
    if (shown == null || !mounted) return;
    widget.auth.markTwoFactor(enabled: true);
    setState(() {
      _setup = null;
      _code.clear();
    });
    await _load();
    if (mounted) await showRecoveryCodes(context, shown);
  }

  Future<void> _regenerate() async {
    final proof = await _askProof(
      context,
      title: AppLocalizations.of(context).secNewCodes,
    );
    if (proof == null) return;
    List<String>? codes;
    await _guard(() async {
      codes = await widget.api.newRecoveryCodes(
        password: proof.password,
        code: proof.code,
        recoveryCode: proof.recovery,
      );
    });
    await _load();
    final shown = codes;
    if (shown != null && mounted) await showRecoveryCodes(context, shown);
  }

  Future<void> _disable() async {
    final l = AppLocalizations.of(context);
    final proof = await _askProof(
      context,
      title: l.secDisable,
      destructive: true,
    );
    if (proof == null) return;
    var done = false;
    await _guard(() async {
      await widget.api.disable(
        password: proof.password,
        code: proof.code,
        recoveryCode: proof.recovery,
      );
      done = true;
    });
    if (!done || !mounted) return;
    widget.auth.markTwoFactor(enabled: false);
    _snack(l.secDisabled);
    await _load();
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _snack(AppLocalizations.of(context).secCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = _status;
    if (status == null) {
      return AppCard(
        child: _error != null
            ? Row(
                children: [
                  Expanded(child: Text(l.secLoadFailed)),
                  TextButton(onPressed: _load, child: Text(l.commonRetry)),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.secTwoFactor,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              StatusPill(
                status.enabled ? l.secOn : l.secOff,
                tone: status.enabled ? Tone.ok : Tone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(l.secTwoFactorHelp),
          if (status.required && !status.enabled) ...[
            const SizedBox(height: 8),
            Text(
              l.secRequiredByCompany,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          if (status.enabled) ..._enabledBody(l, status) else ..._setupBody(l),
        ],
      ),
    );
  }

  List<Widget> _enabledBody(AppLocalizations l, TwoFactorStatus status) => [
    Text(l.secCodesLeft(status.recoveryCodesLeft.toString())),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          key: const ValueKey('two-factor-regenerate'),
          onPressed: _busy ? null : _regenerate,
          child: Text(l.secNewCodes),
        ),
        OutlinedButton(
          key: const ValueKey('two-factor-disable'),
          onPressed: _busy ? null : _disable,
          child: Text(l.secDisable),
        ),
      ],
    ),
  ];

  List<Widget> _setupBody(AppLocalizations l) {
    final setup = _setup;
    if (setup == null) {
      return [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: BusyButton(
            key: const ValueKey('two-factor-enable'),
            label: l.secEnable,
            busy: _busy,
            onPressed: _start,
          ),
        ),
      ];
    }
    return [
      Text(l.secSetupSteps),
      const SizedBox(height: 10),
      _copyRow(l.secSecretKey, setup.secret, 'two-factor-secret'),
      const SizedBox(height: 8),
      _copyRow(l.secSetupLink, setup.otpauthUri, 'two-factor-uri'),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('two-factor-confirm-code'),
        controller: _code,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        maxLength: 6,
        onSubmitted: (_) => _confirm(),
        decoration: InputDecoration(
          labelText: l.secAuthCode,
          errorText: _codeError,
          counterText: '',
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: BusyButton(
          key: const ValueKey('two-factor-confirm'),
          label: l.secConfirmEnable,
          busy: _busy,
          onPressed: _confirm,
        ),
      ),
    ];
  }

  Widget _copyRow(String label, String value, String keyName) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      Row(
        children: [
          Expanded(
            child: SelectableText(
              value,
              key: ValueKey(keyName),
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).secCopy,
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () => _copy(value),
          ),
        ],
      ),
    ],
  );
}

/// What a destructive 2FA action needs: the password plus a current code or a recovery code.
class TwoFactorProof {
  const TwoFactorProof(this.password, {this.code, this.recovery});
  final String password;
  final String? code;
  final String? recovery;
}

Future<TwoFactorProof?> _askProof(
  BuildContext context, {
  required String title,
  bool destructive = false,
}) => showDialog<TwoFactorProof>(
  context: context,
  builder: (_) => _ProofDialog(title: title, destructive: destructive),
);

class _ProofDialog extends StatefulWidget {
  const _ProofDialog({required this.title, required this.destructive});
  final String title;
  final bool destructive;

  @override
  State<_ProofDialog> createState() => _ProofDialogState();
}

class _ProofDialogState extends State<_ProofDialog> {
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _recovery = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    final l = AppLocalizations.of(context);
    final code = _code.text.trim();
    if (_password.text.isEmpty || code.isEmpty) {
      setState(() => _error = l.secProofMissing);
      return;
    }
    Navigator.pop(
      context,
      TwoFactorProof(
        _password.text,
        code: _recovery ? null : code,
        recovery: _recovery ? code : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PasswordField(
              controller: _password,
              label: l.secPassword,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('proof-code'),
              controller: _code,
              textDirection: TextDirection.ltr,
              keyboardType: _recovery
                  ? TextInputType.text
                  : TextInputType.number,
              decoration: InputDecoration(
                labelText: _recovery ? l.secRecoveryCode : l.secAuthCode,
                errorText: _error,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() {
                  _recovery = !_recovery;
                  _code.clear();
                }),
                child: Text(_recovery ? l.secUseAppCode : l.secUseRecoveryCode),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('proof-submit'),
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          onPressed: _submit,
          child: Text(l.commonConfirm),
        ),
      ],
    );
  }
}

/// The one-time recovery codes: shown once, with copy.
Future<void> showRecoveryCodes(BuildContext context, List<String> codes) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return AlertDialog(
          icon: const Icon(Icons.key_outlined),
          title: Text(l.secRecoveryTitle),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.secRecoveryWarning),
                const SizedBox(height: 12),
                for (final c in codes)
                  SelectableText(
                    c,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              key: const ValueKey('recovery-copy'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(ctx);
                await Clipboard.setData(ClipboardData(text: codes.join('\n')));
                messenger.showSnackBar(SnackBar(content: Text(l.secCopied)));
              },
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l.secCopy),
            ),
            FilledButton(
              key: const ValueKey('recovery-done'),
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.secSavedThem),
            ),
          ],
        );
      },
    );
