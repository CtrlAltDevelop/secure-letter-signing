import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/theme/app_theme.dart';

/// The rules behind `strongKeyPassword`, as (label, passes) pairs for a checklist.
List<(String, bool)> passwordRules(String p) => [
  ('At least 10 characters', p.length >= 10),
  ('Uppercase letter', RegExp('[A-Z]').hasMatch(p)),
  ('Lowercase letter', RegExp('[a-z]').hasMatch(p)),
  ('Digit', RegExp('[0-9]').hasMatch(p)),
  ('Symbol', RegExp(r'[^A-Za-z0-9]').hasMatch(p)),
];

/// 0..1 share of rules met (1.0 exactly when `strongKeyPassword` holds).
double passwordStrength(String p) {
  final rules = passwordRules(p);
  return rules.where((r) => r.$2).length / rules.length;
}

/// Strength meter and rule checklist for [password].
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strength = password.isEmpty ? 0.0 : passwordStrength(password);
    final (label, color) = strength == 1
        ? ('Strong', Tokens.ok)
        : strength >= 0.6
        ? ('Almost there', Tokens.warn)
        : ('Weak', Tokens.error);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: strength,
                  color: color,
                  backgroundColor: scheme.outlineVariant,
                  minHeight: 6,
                  semanticsLabel: 'Password strength',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              password.isEmpty ? '' : label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final (text, ok) in passwordRules(password))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ok ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: ok ? Tokens.ok : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ok ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
