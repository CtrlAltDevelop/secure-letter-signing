import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_service.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/sign_widgets.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Initial a letter (paraph) with the signing PIN or this device's fingerprint/face. Pops the
/// sealed [ParaphInfo].
class ParaphScreen extends StatefulWidget {
  const ParaphScreen({super.key, required this.env, required this.letter});
  final LettersEnv env;
  final LetterDetail letter;

  @override
  State<ParaphScreen> createState() => _ParaphScreenState();
}

class _ParaphScreenState extends State<ParaphScreen> {
  final _pin = TextEditingController();
  List<SessionInfo> _sessions = const [];
  bool _busy = false;
  String? _error;
  String? _pinError;

  LettersEnv get env => widget.env;
  LetterDetail get letter => widget.letter;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSessions());
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final all = await env.api.sessions();
      if (mounted) setState(() => _sessions = all);
    } on Exception {
      // The PIN always works.
    }
  }

  bool get _thisDeviceBiometric =>
      _sessions.any((s) => s.current && s.biometric);

  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on LetterException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withPin() async {
    final l = AppLocalizations.of(context);
    final problem = validatePin(_pin.text);
    setState(() => _pinError = problem == null ? null : l.signPinInvalid);
    if (problem != null) return;
    await _guard(() async {
      final p = await env.v2.paraphWithPin(letter.id, _pin.text);
      if (mounted) Navigator.of(context).pop(p);
    });
  }

  Future<void> _withBiometrics() => _guard(() async {
    final l = AppLocalizations.of(context);
    if (!await env.biometrics.authenticate(l.paraphReason(letter.title))) {
      throw LetterException(l.signBiometricFailed);
    }
    final p = await env.v2.paraphWithBiometric(letter.id);
    if (mounted) Navigator.of(context).pop(p);
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.paraphTitle)),
      body: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        letter.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l.paraphExplain,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SectionHeader(l.signHow),
                if (_error != null) ...[
                  ErrorBanner(_error!),
                  const SizedBox(height: 10),
                ],
                SignMethods(
                  pin: _pin,
                  pinError: _pinError,
                  busy: _busy,
                  onPin: _withPin,
                  onBiometric: _thisDeviceBiometric ? _withBiometrics : null,
                  devices: const [],
                  onAsk: (_) {},
                  actionLabel: l.paraphAction,
                ),
                const SizedBox(height: Tokens.gap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
