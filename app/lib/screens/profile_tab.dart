import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/l10n/tr.dart';
import 'package:letter_signing/screens/auth_screens.dart';
import 'package:letter_signing/security/login_history_screen.dart';
import 'package:letter_signing/security/security_api.dart';
import 'package:letter_signing/security/two_factor_card.dart';
import 'package:letter_signing/workspace/workspace_api.dart';
import 'package:letter_signing/screens/signing_pin.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.auth, this.securityApi});
  final AuthController auth;

  /// Replaces the real security API (tests).
  final SecurityApi? securityApi;

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
  late final SecurityApi _security =
      widget.securityApi ?? SecurityApi(WorkspaceApi(widget.auth.api));

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
    if (ok) _toast(tr.profileSaved);
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
    _toast(tr.profilePasswordChanged);
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
                              StatusPill(tr.profileManager, tone: Tone.info),
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
            SectionHeader(tr.profileSection),
            AppCard(
              child: Form(
                key: _profileForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(
                      _name,
                      tr.authFullName,
                      Icons.person_outline,
                      validator: requiredField(tr.profileEnterName),
                    ),
                    const SizedBox(height: 14),
                    _field(_title, tr.profileJobTitle, Icons.work_outline),
                    const SizedBox(height: 14),
                    _field(
                      _department,
                      tr.profileDepartmentReadonly,
                      Icons.apartment_outlined,
                      enabled: false,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: BusyButton(
                        label: tr.commonSave,
                        busy: _saving,
                        onPressed: _saveProfile,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SectionHeader(
              tr.authSigningPin,
              subtitle: widget.auth.user?.hasSigningPin ?? false
                  ? tr.profilePinChangeSubtitle
                  : tr.profilePinSetSubtitle,
            ),
            AppCard(
              child: SigningPinForm(
                auth: widget.auth,
                onDone: () => _toast(tr.profilePinSaved),
              ),
            ),
            SectionHeader(
              tr.profileChangePassword,
              subtitle: tr.profileChangePasswordSubtitle,
            ),
            AppCard(
              child: Form(
                key: _passwordForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PasswordField(
                      controller: _current,
                      label: tr.profileCurrentPassword,
                      validator: requiredField(tr.profileEnterCurrentPassword),
                      autofillHints: const [AutofillHints.password],
                    ),
                    const SizedBox(height: 14),
                    PasswordField(
                      controller: _next,
                      label: tr.authNewPassword,
                      helper: passwordHint,
                      validator: validateNewPassword,
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: _changePassword,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: BusyButton(
                        label: tr.profileChangePassword,
                        tonal: true,
                        busy: _changing,
                        onPressed: _changePassword,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SectionHeader(AppLocalizations.of(context).secTitle),
            TwoFactorCard(api: _security, auth: widget.auth),
            const SizedBox(height: 8),
            AppCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      LoginHistoryScreen(load: _security.myLoginHistory),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(AppLocalizations.of(context).secLoginHistory),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: Tokens.gap),
          ],
        ),
      ),
    );
  }
}
