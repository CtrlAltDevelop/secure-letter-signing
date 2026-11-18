import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/screens/auth_screens.dart';
import 'package:letter_signing/screens/signing_pin.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _profileForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.auth.user?.fullName);
  late final _title = TextEditingController(text: widget.auth.user?.title);
  late final _department = TextEditingController(
    text: widget.auth.user?.department,
  );
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _saving = false;
  bool _changing = false;

  @override
  void dispose() {
    for (final c in [_name, _title, _department, _current, _next]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_saving || !_profileForm.currentState!.validate()) return;
    setState(() {
      _saving = true;
    });
    final ok = await runGuarded(
      context,
      () => widget.auth.updateProfile(fullName: _name.text, title: _title.text),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
    });
    if (ok) _toast('Saved');
  }

  Future<void> _changePassword() async {
    if (_changing || !_passwordForm.currentState!.validate()) return;
    setState(() {
      _changing = true;
    });
    final ok = await runGuarded(
      context,
      () => widget.auth.changePassword(_current.text, _next.text),
    );
    if (!mounted) return;
    setState(() {
      _changing = false;
    });
    if (!ok) return;
    _current.clear();
    _next.clear();
    _passwordForm.currentState?.reset();
    _toast('Password changed; other devices were signed out');
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    bool enabled = true,
  }) => TextFormField(
    controller: c,
    enabled: enabled,
    validator: validator,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
  );

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final name = user?.fullName ?? '';
    final email = user?.email ?? '';
    return SingleChildScrollView(
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Row(
                children: [
                  UserAvatar(fullName: name, email: email, radius: 32),
                  const SizedBox(width: Tokens.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? email : name,
                          style: text.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (name.isNotEmpty)
                          Text(
                            email,
                            style: text.bodyMedium?.copyWith(color: muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (user?.isManager ?? false)
                              const StatusPill('Manager', tone: Tone.info),
                            for (final p
                                in user?.permissions ?? const <String>[])
                              StatusPill(permissionLabel(p)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SectionHeader('Profile'),
            AppCard(
              child: Form(
                key: _profileForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(
                      _name,
                      'Full name',
                      Icons.person_outline,
                      validator: requiredField('Enter your name'),
                    ),
                    const SizedBox(height: 14),
                    _field(_title, 'Job title', Icons.work_outline),
                    const SizedBox(height: 14),
                    _field(
                      _department,
                      'Department (set by the manager)',
                      Icons.apartment_outlined,
                      enabled: false,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: BusyButton(
                        label: 'Save',
                        busy: _saving,
                        onPressed: _saveProfile,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SectionHeader(
              'Signing PIN',
              subtitle: widget.auth.user?.hasSigningPin ?? false
                  ? 'Change the 6-digit PIN that confirms your signatures'
                  : 'Set the 6-digit PIN that confirms your signatures',
            ),
            AppCard(
              child: SigningPinForm(
                auth: widget.auth,
                onDone: () => _toast('Signing PIN saved'),
              ),
            ),
            const SectionHeader(
              'Change password',
              subtitle: 'Other devices are signed out afterwards',
            ),
            AppCard(
              child: Form(
                key: _passwordForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PasswordField(
                      controller: _current,
                      label: 'Current password',
                      validator: requiredField('Enter your current password'),
                      autofillHints: const [AutofillHints.password],
                    ),
                    const SizedBox(height: 14),
                    PasswordField(
                      controller: _next,
                      label: 'New password',
                      helper: passwordHint,
                      validator: validateNewPassword,
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: _changePassword,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: BusyButton(
                        label: 'Change password',
                        tonal: true,
                        busy: _changing,
                        onPressed: _changePassword,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Tokens.gap),
          ],
        ),
      ),
    );
  }
}
