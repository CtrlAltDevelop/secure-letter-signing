import 'package:material_ui/material_ui.dart';

/// Small helpers shared by the screens in this folder.

final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
const minPasswordLength = 8;
const passwordHint =
    'At least $minPasswordLength characters; avoid common ones';

String? validateEmail(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'Enter your email';
  return _emailShape.hasMatch(t) ? null : 'Enter a valid email address';
}

String? validateNewPassword(String? v) => (v ?? '').length >= minPasswordLength
    ? null
    : 'Use at least $minPasswordLength characters';

String? Function(String?) requiredField(String message) =>
    (v) => (v ?? '').trim().isEmpty ? message : null;

String initialsOf(String fullName, String email) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty);
  final source = parts.isEmpty ? [email.split('@').first] : parts.toList();
  final letters = source.take(2).map((p) => p.characters.first.toUpperCase());
  final out = letters.join();
  return out.isEmpty ? '?' : out;
}

const _permissionLabels = {
  'user': 'Member',
  'letter.create': 'Create letters',
  'letter.see': 'See letters',
  'letter.sign': 'Sign letters',
};

String permissionLabel(String code) => _permissionLabels[code] ?? code;

/// "just now", "5 min ago", "3 h ago", "2 d ago"; falls back to the raw text.
String relativeTime(Object? iso, {DateTime? now}) {
  final t = DateTime.tryParse('$iso');
  if (t == null) return '$iso';
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 30) return '${d.inDays} d ago';
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.fullName,
    required this.email,
    this.radius = 20,
  });
  final String fullName;
  final String email;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary.withValues(alpha: 0.16),
      child: Text(
        initialsOf(fullName, email),
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

/// Password input with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.helper,
    this.validator,
    this.autofillHints,
    this.onSubmitted,
    this.textInputAction,
  });
  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final VoidCallback? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _hidden,
    autofillHints: widget.autofillHints,
    validator: widget.validator,
    textInputAction: widget.textInputAction,
    onFieldSubmitted: (_) => widget.onSubmitted?.call(),
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: widget.label,
      helperText: widget.helper,
      helperMaxLines: 2,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: _hidden ? 'Show password' : 'Hide password',
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: () {
          setState(() {
            _hidden = !_hidden;
          });
        },
      ),
    ),
  );
}

/// FilledButton that disables itself and shows a spinner while [busy].
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.tonal = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Text(label);
    final action = busy ? null : onPressed;
    return tonal
        ? FilledButton.tonal(onPressed: action, child: child)
        : FilledButton(onPressed: action, child: child);
  }
}
