import 'package:material_ui/material_ui.dart';

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
    final strength = passwordStrength(password);
    final color = strength == 1
        ? Colors.green
        : strength >= 0.6
        ? Colors.orange
        : Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: strength,
          color: color,
          minHeight: 6,
          semanticsLabel: 'Password strength',
        ),
        const SizedBox(height: 8),
        for (final (label, ok) in passwordRules(password))
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle : Icons.circle_outlined,
                size: 16,
                color: ok ? Colors.green : null,
              ),
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
      ],
    );
  }
}
