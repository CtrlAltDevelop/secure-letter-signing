import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/l10n/tr.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/security/two_factor_login_screen.dart';
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
    messenger.showSnackBar(SnackBar(content: Text(tr.authServerUnreachable)));
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
  decoration: InputDecoration(
    labelText: tr.authEmail,
    prefixIcon: const Icon(Icons.mail_outline),
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

Widget _linkRow(List<Widget> links) => Wrap(
  alignment: WrapAlignment.center,
  crossAxisAlignment: WrapCrossAlignment.center,
  spacing: 4,
  children: links,
);

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
    var signedIn = true;
    final ok = await runGuarded(context, () async {
      signedIn = await widget.auth.login(
        _email.text.trim(),
        _password.text,
        deviceName: Theme.of(context).platform.name,
        platform: Theme.of(context).platform.name,
      );
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
    });
    if (ok && !signedIn) {
      _push(context, TwoFactorLoginScreen(auth: widget.auth));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr.authWelcomeTitle,
      subtitle: tr.authWelcomeSubtitle,
      footer: _linkRow([
        Text(tr.authNewHere),
        TextButton(
          onPressed: () => _push(context, SignupScreen(auth: widget.auth)),
          child: Text(tr.authCreateAccount),
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
                validator: requiredField(tr.authEnterPassword),
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
              ),
            ],
          ),
        ),
        BusyButton(label: tr.authSignIn, busy: _busy, onPressed: _submit),
        Center(
          child: TextButton(
            onPressed: () => _push(context, ResetScreen(auth: widget.auth)),
            child: Text(tr.authForgotPassword),
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
      _snack(context, tr.authRegistered);
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
      _snack(context, tr.authEmailVerified);
    }
  }

  @override
  Widget build(BuildContext context) {
    final back = _backLink(context);
    if (_awaitingVerification) {
      return AuthScaffold(
        title: tr.authCheckEmailTitle,
        subtitle: tr.authCheckEmailSubtitle,
        footer: back,
        children: [
          TextField(
            controller: _token,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verify(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: tr.authVerifyTokenLabel,
              prefixIcon: const Icon(Icons.key_outlined),
            ),
          ),
          BusyButton(
            label: tr.authVerify,
            busy: _busy,
            onPressed: _token.text.trim().isEmpty ? null : _verify,
          ),
        ],
      );
    }
    return AuthScaffold(
      title: tr.authCreateAccount,
      subtitle: tr.authSignupSubtitle,
      footer: back,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _textField(
                _name,
                tr.authFullName,
                Icons.person_outline,
                validator: requiredField(tr.authEnterFullName),
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
                tr.authInviteCodeOptional,
                Icons.confirmation_number_outlined,
                helper: tr.authInviteHelper,
                action: TextInputAction.done,
              ),
            ],
          ),
        ),
        BusyButton(label: tr.authSignUp, busy: _busy, onPressed: _signup),
      ],
    );
  }

  Widget _backLink(BuildContext context) => _linkRow([
    Text(tr.authHaveAccount),
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(tr.authBackToSignIn),
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
    if (ok) _snack(context, tr.authResetRequested);
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
      _snack(context, tr.authPasswordChangedSignIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AuthScaffold(
      title: tr.authResetTitle,
      subtitle: tr.authResetSubtitle,
      showBack: true,
      footer: _linkRow([
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr.authBackToSignIn),
        ),
      ]),
      children: [
        Form(
          key: _requestForm,
          child: _emailField(_email, action: TextInputAction.done),
        ),
        BusyButton(
          label: tr.authEmailMeToken,
          tonal: true,
          busy: _requesting,
          onPressed: _request,
        ),
        const Divider(height: 24),
        Text(tr.authHaveToken, style: TextStyle(color: muted)),
        Form(
          key: _confirmForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _textField(
                _token,
                tr.authToken,
                Icons.key_outlined,
                validator: requiredField(tr.authEnterToken),
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                label: tr.authNewPassword,
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
          label: tr.authSetNewPassword,
          busy: _confirming,
          onPressed: _confirm,
        ),
      ],
    );
  }
}
