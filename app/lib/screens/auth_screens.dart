import 'package:flutter/material.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/api/auth_controller.dart';

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    setState(() => _busy = true);
    await runGuarded(
      context,
      () => widget.auth.login(
        _email.text.trim(),
        _password.text,
        deviceName: Theme.of(context).platform.name,
        platform: Theme.of(context).platform.name,
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: const Text('Sign in'),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SignupScreen(auth: widget.auth),
                  ),
                ),
                child: const Text('Create account'),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ResetScreen(auth: widget.auth),
                  ),
                ),
                child: const Text('Forgot password'),
              ),
            ],
          ),
        ),
      ),
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
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _invite = TextEditingController();
  final _token = TextEditingController();
  bool _awaitingVerification = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _invite, _token]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _signup() async {
    SignupResult? result;
    final ok = await runGuarded(context, () async {
      result = await widget.auth.signup(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _name.text.trim(),
        inviteCode: _invite.text.trim(),
      );
    });
    if (!ok || !mounted) return;
    if (result == SignupResult.registered) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registered. Sign in now.')));
    } else {
      setState(() => _awaitingVerification = true);
    }
  }

  Future<void> _verify() async {
    final ok = await runGuarded(
      context,
      () => widget.auth.verifyEmail(_token.text.trim()),
    );
    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verified. Sign in now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: _awaitingVerification
                ? [
                    const Text('Paste the token we emailed you.'),
                    TextField(
                      controller: _token,
                      decoration: const InputDecoration(
                        labelText: 'Verification token',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _verify,
                      child: const Text('Verify'),
                    ),
                  ]
                : [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    TextField(
                      controller: _invite,
                      decoration: const InputDecoration(
                        labelText: 'Invitation code',
                        helperText:
                            'Leave empty to sign up with your company email',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _signup,
                      child: const Text('Sign up'),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

class ResetScreen extends StatefulWidget {
  const ResetScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends State<ResetScreen> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    for (final c in [_email, _token, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _request() async {
    final ok = await runGuarded(
      context,
      () => widget.auth.requestReset(_email.text.trim()),
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('If the account exists, a token was emailed.'),
        ),
      );
    }
  }

  Future<void> _confirm() async {
    final ok = await runGuarded(
      context,
      () => widget.auth.confirmReset(_token.text.trim(), _password.text),
    );
    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed. Sign in now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextButton(
                onPressed: _request,
                child: const Text('Email me a token'),
              ),
              const Divider(),
              const Text('Have a token (emailed, or given by your manager)?'),
              TextField(
                controller: _token,
                decoration: const InputDecoration(labelText: 'Token'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _confirm,
                child: const Text('Set new password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
