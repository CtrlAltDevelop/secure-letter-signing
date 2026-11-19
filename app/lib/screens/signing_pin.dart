import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/l10n/tr.dart';
import 'package:letter_signing/screens/auth_screens.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Form for choosing the 6-digit signing PIN: PIN, repeat, and the login password as proof.
class SigningPinForm extends StatefulWidget {
  const SigningPinForm({super.key, required this.auth, this.onDone});
  final AuthController auth;

  /// Called after the server accepted the new PIN.
  final VoidCallback? onDone;

  @override
  State<SigningPinForm> createState() => _SigningPinFormState();
}

class _SigningPinFormState extends State<SigningPinForm> {
  final _form = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _repeat = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    _repeat.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateRepeat(String? v) {
    final pinProblem = validatePin(v);
    if (pinProblem != null) return pinProblem;
    return v == _pin.text ? null : tr.pinMismatch;
  }

  Future<void> _submit() async {
    final state = _form.currentState;
    if (_busy || state == null || !state.validate()) return;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => widget.auth.setSigningPin(_pin.text, _password.text),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    _pin.clear();
    _repeat.clear();
    _password.clear();
    _form.currentState?.reset();
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PinField(
          controller: _pin,
          label: tr.pinNewLabel,
          validator: validatePin,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        PinField(
          controller: _repeat,
          label: tr.pinRepeatLabel,
          validator: _validateRepeat,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        PasswordField(
          controller: _password,
          label: tr.pinLoginPassword,
          validator: requiredField(tr.pinEnterLoginPassword),
          autofillHints: const [AutofillHints.password],
          onSubmitted: _submit,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: BusyButton(label: tr.pinSave, busy: _busy, onPressed: _submit),
        ),
      ],
    ),
  );
}

/// Full-screen step shown before the app shell until the account has a signing PIN.
class SigningPinGate extends StatelessWidget {
  const SigningPinGate({super.key, required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: tr.pinGateTitle,
    subtitle: tr.pinGateSubtitle,
    footer: TextButton(
      onPressed: auth.logout,
      child: Text(tr.sessionsSignOutAction),
    ),
    children: [SigningPinForm(auth: auth)],
  );
}
