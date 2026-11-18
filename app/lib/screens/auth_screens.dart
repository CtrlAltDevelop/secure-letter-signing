import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Runs [action], shows server errors in a snackbar. Returns true on success.
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } on Exception {
    messenger.showSnackBar(
      const SnackBar(content: Text('Cannot reach the server')),
    );
  }
  return false;
}

TextFormField _emailField(
  TextEditingController c, {
  TextInputAction action = TextInputAction.next,
}) => TextFormField(
  controller: c,
  keyboardType: TextInputType.emailAddress,
  autofillHints: const [AutofillHints.email],
  textInputAction: action,
  validator: validateEmail,
  autovalidateMode: AutovalidateMode.onUserInteraction,
  decoration: const InputDecoration(
    labelText: 'Email',
    prefixIcon: Icon(Icons.mail_outline),
  ),
);

TextFormField _textField(
  TextEditingController c,
  String label,
  IconData icon, {
  String? helper,
  String? Function(String?)? validator,
  TextInputAction action = TextInputAction.next,
}) => TextFormField(
  controller: c,
  textInputAction: action,
  validator: validator,
  autovalidateMode: AutovalidateMode.onUserInteraction,
  decoration: InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 2,
    prefixIcon: Icon(icon),
  ),
);

Widget _linkRow(List<Widget> links) =>
    Wrap(alignment: WrapAlignment.center, spacing: 4, children: links);

void _push(BuildContext context, Widget screen) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
    });
    await runGuarded(
      context,
      () => widget.auth.login(
        _email.text.trim(),
        _password.text,
        deviceName: Theme.of(context).platform.name,
        platform: Theme.of(context).platform.name,
      ),
    );
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue',
      footer: _linkRow([
        const Text('New here?'),
        TextButton(
          onPressed: () => _push(context, SignupScreen(auth: widget.auth)),
          child: const Text('Create account'),
        ),
      ]),
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _emailField(_email),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                autofillHints: const [AutofillHints.password],
                validator: requiredField('Enter your password'),
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
              ),
            ],
          ),
        ),
        BusyButton(label: 'Sign in', busy: _busy, onPressed: _submit),
        Center(
          child: TextButton(
            onPressed: () => _push(context, ResetScreen(auth: widget.auth)),
            child: const Text('Forgot password'),
          ),
        ),
      ],
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _invite = TextEditingController();
  final _token = TextEditingController();
  bool _awaitingVerification = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _invite, _token]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _signup() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
    });
    SignupResult? result;
    final ok = await runGuarded(context, () async {
      result = await widget.auth.signup(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _name.text.trim(),
        inviteCode: _invite.text.trim(),
      );
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
    });
    if (!ok) return;
    if (result == SignupResult.registered) {
      Navigator.pop(context);
      _snack(context, 'Registered. Sign in now.');
    } else {
      setState(() {
        _awaitingVerification = true;
      });
    }
  }

  Future<void> _verify() async {
    if (_busy || _token.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
    });
    final ok = await runGuarded(
      context,
      () => widget.auth.verifyEmail(_token.text.trim()),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
    });
    if (ok) {
      Navigator.pop(context);
      _snack(context, 'Email verified. Sign in now.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final back = _backLink(context);
    if (_awaitingVerification) {
      return AuthScaffold(
        title: 'Check your email',
        subtitle: 'Paste the token we emailed you to verify your address.',
        showBack: true,
        footer: back,
        children: [
          TextField(
            controller: _token,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verify(),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Verification token',
              prefixIcon: Icon(Icons.key_outlined),
            ),
          ),
          BusyButton(
            label: 'Verify',
            busy: _busy,
            onPressed: _token.text.trim().isEmpty ? null : _verify,
          ),
        ],
      );
    }
    return AuthScaffold(
      title: 'Create account',
      subtitle: 'Join your company workspace',
      showBack: true,
      footer: back,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _textField(
                _name,
                'Full name',
                Icons.person_outline,
                validator: requiredField('Enter your full name'),
              ),
              const SizedBox(height: 14),
              _emailField(_email),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                helper: passwordHint,
                validator: validateNewPassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              _textField(
                _invite,
                'Invitation code (optional)',
                Icons.confirmation_number_outlined,
                helper: 'Leave empty to sign up with your company email',
                action: TextInputAction.done,
              ),
            ],
          ),
        ),
        BusyButton(label: 'Sign up', busy: _busy, onPressed: _signup),
      ],
    );
  }

  Widget _backLink(BuildContext context) => _linkRow([
    const Text('Already have an account?'),
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Back to sign in'),
    ),
  ]);
}

class ResetScreen extends StatefulWidget {
  const ResetScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends State<ResetScreen> {
  final _requestForm = GlobalKey<FormState>();
  final _confirmForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  bool _requesting = false;
  bool _confirming = false;

  @override
  void dispose() {
    for (final c in [_email, _token, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _request() async {
    if (_requesting || !_requestForm.currentState!.validate()) return;
    setState(() {
      _requesting = true;
    });
    final ok = await runGuarded(
      context,
      () => widget.auth.requestReset(_email.text.trim()),
    );
    if (!mounted) return;
    setState(() {
      _requesting = false;
    });
    if (ok) _snack(context, 'If the account exists, a token was emailed.');
  }

  Future<void> _confirm() async {
    if (_confirming || !_confirmForm.currentState!.validate()) return;
    setState(() {
      _confirming = true;
    });
    final ok = await runGuarded(
      context,
      () => widget.auth.confirmReset(_token.text.trim(), _password.text),
    );
    if (!mounted) return;
    setState(() {
      _confirming = false;
    });
    if (ok) {
      Navigator.pop(context);
      _snack(context, 'Password changed. Sign in now.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AuthScaffold(
      title: 'Reset password',
      subtitle: 'We email you a token, then you choose a new password.',
      showBack: true,
      footer: _linkRow([
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to sign in'),
        ),
      ]),
      children: [
        Form(
          key: _requestForm,
          child: _emailField(_email, action: TextInputAction.done),
        ),
        BusyButton(
          label: 'Email me a token',
          tonal: true,
          busy: _requesting,
          onPressed: _request,
        ),
        const Divider(height: 24),
        Text(
          'Have a token (emailed, or given by your manager)?',
          style: TextStyle(color: muted),
        ),
        Form(
          key: _confirmForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _textField(
                _token,
                'Token',
                Icons.key_outlined,
                validator: requiredField('Enter the token'),
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                label: 'New password',
                helper: passwordHint,
                validator: validateNewPassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: _confirm,
              ),
            ],
          ),
        ),
        BusyButton(
          label: 'Set new password',
          busy: _confirming,
          onPressed: _confirm,
        ),
      ],
    );
  }
}
