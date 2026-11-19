import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/prefs/prefs_controller.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Connect a personal email (a signed token is mailed) and verify it by pasting the token.
class PersonalEmailCard extends StatefulWidget {
  const PersonalEmailCard({super.key, required this.controller});
  final PrefsController controller;

  @override
  State<PersonalEmailCard> createState() => _PersonalEmailCardState();
}

class _PersonalEmailCardState extends State<PersonalEmailCard> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  bool _sent = false;
  String? _message;

  PrefsController get c => widget.controller;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _send(AppLocalizations l) async {
    final ok = await c.setPersonalEmail(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _sent = ok;
      _message = ok ? l.personalEmailSent : l.personalEmailFailed;
    });
  }

  Future<void> _verify(AppLocalizations l) async {
    final ok = await c.verifyPersonalEmail(_token.text.trim());
    if (!mounted) return;
    setState(() {
      if (ok) _sent = false;
      _message = ok ? l.personalEmailVerified : l.personalEmailBadToken;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = c.prefs;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.personalEmailTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (p.personalEmail.isNotEmpty)
            Text(
              '${p.personalEmail} - ${p.personalEmailVerified ? l.personalEmailVerifiedBadge : l.personalEmailUnverified}',
              key: const ValueKey('pe-state'),
            ),
          TextField(
            key: const ValueKey('pe-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: l.personalEmailField),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const ValueKey('pe-send'),
              onPressed: () => unawaited(_send(l)),
              child: Text(l.personalEmailSend),
            ),
          ),
          if (_sent ||
              (p.personalEmail.isNotEmpty && !p.personalEmailVerified)) ...[
            TextField(
              key: const ValueKey('pe-token'),
              controller: _token,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: l.personalEmailToken),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const ValueKey('pe-verify'),
                onPressed: () => unawaited(_verify(l)),
                child: Text(l.personalEmailVerify),
              ),
            ),
          ],
          if (_message != null) Text(_message!, key: const ValueKey('pe-msg')),
        ],
      ),
    );
  }
}
