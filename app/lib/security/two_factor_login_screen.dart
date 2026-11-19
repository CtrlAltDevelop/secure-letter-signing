import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/screens/ui_bits.dart';

/// Second step of the login: the 6-digit code of the authenticator app, or a recovery code.
/// On success [AuthController] signs in (the app shell swaps to Home) and this route closes.
class TwoFactorLoginScreen extends StatefulWidget {
  const TwoFactorLoginScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<TwoFactorLoginScreen> createState() => _TwoFactorLoginScreenState();
}

class _TwoFactorLoginScreenState extends State<TwoFactorLoginScreen> {
  final _code = TextEditingController();
  bool _recovery = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool get _valid {
    final v = _code.text.trim();
    return _recovery ? v.length >= 6 : RegExp(r'^\d{6}$').hasMatch(v);
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_busy) return;
    if (!_valid) {
      setState(
        () => _error = _recovery ? l.secCodeRecoveryInvalid : l.secCodeInvalid,
      );
      return;
    }
    final platform = Theme.of(context).platform.name;
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.completeTwoFactor(
        _code.text.trim(),
        recovery: _recovery,
        deviceName: platform,
        platform: platform,
      );
      if (mounted) nav.popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Exception {
      if (mounted) setState(() => _error = l.secNoConnection);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      title: l.secLoginCodeTitle,
      subtitle: _recovery ? l.secLoginRecoverySubtitle : l.secLoginCodeSubtitle,
      showBack: true,
      children: [
        TextField(
          key: const ValueKey('two-factor-code'),
          controller: _code,
          autofocus: true,
          keyboardType: _recovery ? TextInputType.text : TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLength: _recovery ? 32 : 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: _recovery ? l.secRecoveryCode : l.secAuthCode,
            errorText: _error,
            errorMaxLines: 3,
            counterText: '',
            prefixIcon: const Icon(Icons.shield_outlined),
          ),
        ),
        const SizedBox(height: 14),
        BusyButton(label: l.secContinue, busy: _busy, onPressed: _submit),
        Center(
          child: TextButton(
            key: const ValueKey('two-factor-toggle'),
            onPressed: () => setState(() {
              _recovery = !_recovery;
              _error = null;
              _code.clear();
            }),
            child: Text(_recovery ? l.secUseAppCode : l.secUseRecoveryCode),
          ),
        ),
      ],
    );
  }
}
