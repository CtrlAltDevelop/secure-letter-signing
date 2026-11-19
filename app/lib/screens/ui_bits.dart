import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/tr.dart';

/// Small helpers shared by the screens in this folder.

final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
const minPasswordLength = 8;
String get passwordHint => tr.authPasswordHint('$minPasswordLength');

String? validateEmail(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return tr.authEnterEmail;
  return _emailShape.hasMatch(t) ? null : tr.authEnterValidEmail;
}

String? validateNewPassword(String? v) => (v ?? '').length >= minPasswordLength
    ? null
    : tr.authPasswordTooShort('$minPasswordLength');

/// The signing PIN is exactly this many digits.
const signingPinLength = 6;

bool isValidPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

String? validatePin(String? v) =>
    isValidPin(v ?? '') ? null : tr.authPinDigits('$signingPinLength');

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

String permissionLabel(String code) => switch (code) {
  'user' => tr.permMember,
  'letter.create' => tr.permLetterCreate,
  'letter.see' => tr.permLetterSee,
  'letter.sign' => tr.permLetterSign,
  _ => code,
};

/// "just now", "5 min ago", "3 h ago", "2 d ago" (Persian); falls back to the raw text.
String relativeTime(Object? iso, {DateTime? now}) {
  final t = DateTime.tryParse('$iso');
  if (t == null) return '$iso';
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return tr.relTimeNow;
  if (d.inMinutes < 60) return tr.relTimeMinutes('${d.inMinutes}');
  if (d.inHours < 24) return tr.relTimeHours('${d.inHours}');
  if (d.inDays < 30) return tr.relTimeDays('${d.inDays}');
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
    this.label,
    this.helper,
    this.validator,
    this.autofillHints,
    this.onSubmitted,
    this.textInputAction,
  });
  final TextEditingController controller;
  final String? label;
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
      labelText: widget.label ?? tr.authPassword,
      helperText: widget.helper,
      helperMaxLines: 2,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: _hidden ? tr.authShowPassword : tr.authHidePassword,
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

/// Obscured numeric field for the 6-digit signing PIN.
class PinField extends StatelessWidget {
  const PinField({
    super.key,
    required this.controller,
    this.label,
    this.errorText,
    this.validator,
    this.onSubmitted,
    this.enabled = true,
    this.textInputAction,
  });
  final TextEditingController controller;
  final String? label;
  final String? errorText;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;
  final bool enabled;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    obscureText: true,
    enableSuggestions: false,
    autocorrect: false,
    keyboardType: TextInputType.number,
    textInputAction: textInputAction,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(signingPinLength),
    ],
    validator: validator,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    onFieldSubmitted: (_) => onSubmitted?.call(),
    decoration: InputDecoration(
      labelText: label ?? tr.authSigningPin,
      errorText: errorText,
      prefixIcon: const Icon(Icons.pin_outlined),
    ),
  );
}

IconData platformIcon(String platform) => switch (platform.toLowerCase()) {
  'android' || 'ios' || 'iphone' => Icons.smartphone,
  'macos' || 'windows' || 'linux' => Icons.laptop_mac,
  _ => Icons.devices_other,
};
