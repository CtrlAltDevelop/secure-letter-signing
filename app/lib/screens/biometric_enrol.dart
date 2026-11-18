import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/screens/ui_bits.dart';

/// Runs the local check then enrols the session. True = enrolled, false = the
/// fingerprint/face check was cancelled (nothing was sent).
typedef EnrollBiometric = Future<bool> Function(String pin);

/// Asks for the signing PIN and enrols this device's fingerprint/face.
/// Resolves to true when the session was enrolled, false for "Not now".
Future<bool> showBiometricEnrolDialog(
  BuildContext context, {
  required EnrollBiometric enroll,
}) async {
  final enabled = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BiometricEnrolDialog(enroll: enroll),
  );
  return enabled ?? false;
}

class BiometricEnrolDialog extends StatefulWidget {
  const BiometricEnrolDialog({super.key, required this.enroll});
  final EnrollBiometric enroll;

  @override
  State<BiometricEnrolDialog> createState() => _BiometricEnrolDialogState();
}

class _BiometricEnrolDialogState extends State<BiometricEnrolDialog> {
  final _form = GlobalKey<FormState>();
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _enable() async {
    final state = _form.currentState;
    if (_busy || state == null || !state.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    var enabled = false;
    try {
      enabled = await widget.enroll(_pin.text);
      if (!enabled) error = 'Fingerprint / face check was cancelled';
    } on BiometricEnrolError catch (e) {
      error = e.message;
    } on ApiException catch (e) {
      error = e.message;
    } on Exception {
      error = 'Cannot reach the server';
    }
    if (!mounted) return;
    if (enabled) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Use fingerprint / face on this device'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Approve signatures without typing your PIN, and let your '
                'other devices ask this one to approve. Confirm with your '
                'signing PIN once to turn it on.',
              ),
              const SizedBox(height: 16),
              PinField(
                controller: _pin,
                enabled: !_busy,
                validator: validatePin,
                onSubmitted: _enable,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: _busy ? null : _enable,
          child: const Text('Enable'),
        ),
      ],
    );
  }
}

/// Shows the enrolment dialog once per app run, when the controller asks for it.
class BiometricEnrolPrompt extends StatefulWidget {
  const BiometricEnrolPrompt({
    super.key,
    required this.auth,
    required this.child,
  });
  final AuthController auth;
  final Widget child;

  @override
  State<BiometricEnrolPrompt> createState() => _BiometricEnrolPromptState();
}

class _BiometricEnrolPromptState extends State<BiometricEnrolPrompt> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    widget.auth.removeListener(_check);
    super.dispose();
  }

  Future<void> _check() async {
    if (_open || !mounted || !widget.auth.needsBiometricEnrolment) return;
    _open = true;
    final enabled = await showBiometricEnrolDialog(
      context,
      enroll: widget.auth.enrollBiometric,
    );
    _open = false;
    if (!enabled) widget.auth.dismissBiometricEnrolment();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
