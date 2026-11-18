import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/crypto/crypto_primitives.dart';
import 'package:letter_signing/keys/key_models.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Runs [action] and reports failures in a snackbar. Returns true on success.
Future<bool> runKeyAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  final String message;
  try {
    await action();
    return true;
  } on ApiException catch (e) {
    message = e.message;
  } on KeyException catch (e) {
    message = e.message;
  } on WrongPasswordException {
    message = 'Wrong password';
  } on CryptoException catch (e) {
    message = e.message;
  } on Exception {
    message = 'Cannot reach the server';
  }
  // Callers may run from initState; inherited widgets cannot be read until it has finished, so
  // yield first and look the messenger up afterwards (and only if the screen is still there).
  await Future<void>.value();
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
  return false;
}

/// Groups a fingerprint in blocks of four characters for easier reading aloud.
String groupFingerprint(String fp) {
  final clean = fp.replaceAll(RegExp(r'\s'), '');
  return [
    for (var i = 0; i < clean.length; i += 4)
      clean.substring(i, i + 4 > clean.length ? clean.length : i + 4),
  ].join(' ');
}

/// A fingerprint in monospace, grouped and selectable so it can be compared or copied.
class FingerprintText extends StatelessWidget {
  const FingerprintText(this.fingerprint, {super.key, this.large = false});
  final String fingerprint;
  final bool large;

  @override
  Widget build(BuildContext context) => SelectableText(
    groupFingerprint(fingerprint),
    style: TextStyle(
      fontFamily: 'monospace',
      fontSize: large ? 20 : 13,
      height: 1.5,
      letterSpacing: 0.5,
      fontWeight: large ? FontWeight.w600 : FontWeight.w500,
    ),
  );
}

/// A fingerprint on a tinted, rounded panel.
class FingerprintPanel extends StatelessWidget {
  const FingerprintPanel(this.fingerprint, {super.key, this.large = false});
  final String fingerprint;
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(Tokens.radiusSmall),
    ),
    child: FingerprintText(fingerprint, large: large),
  );
}

/// Password field with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.autofocus = false,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final bool autofocus;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    obscureText: _hidden,
    autofocus: widget.autofocus,
    enabled: widget.enabled,
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      labelText: widget.label,
      errorText: widget.errorText,
      suffixIcon: IconButton(
        tooltip: _hidden ? 'Show password' : 'Hide password',
        icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
        onPressed: () {
          setState(() {
            _hidden = !_hidden;
          });
        },
      ),
    ),
  );
}

/// Inline message box (error, warning, info) with an icon.
class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.tone = Tone.info, this.action});
  final String message;
  final Tone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      Tone.ok => Tokens.ok,
      Tone.warn => Tokens.warn,
      Tone.error => Tokens.error,
      _ => scheme.primary,
    };
    final icon = switch (tone) {
      Tone.ok => Icons.check_circle_outline,
      Tone.warn => Icons.warning_amber_rounded,
      Tone.error => Icons.error_outline,
      _ => Icons.info_outline,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Tokens.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: TextStyle(color: scheme.onSurface)),
                ?action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Page frame for a keys screen: normal Scaffold with AppBar, or just the body when [embedded]
/// (the app shell already provides the AppBar).
class KeysPage extends StatelessWidget {
  const KeysPage({
    super.key,
    required this.title,
    required this.embedded,
    required this.body,
    this.actions = const [],
  });
  final String title;
  final bool embedded;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => embedded
      ? body
      : Scaffold(
          appBar: AppBar(title: Text(title), actions: actions),
          body: body,
        );
}

Tone statusTone(String status) => switch (status) {
  'active' => Tone.ok,
  'pending' => Tone.warn,
  _ => Tone.neutral,
};

/// Large fingerprint for reading out or comparing with the owner.
Future<void> showFingerprintDialog(
  BuildContext context,
  String title,
  String fingerprint,
) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compare this with the fingerprint shown on the owner\'s device, in person or by phone.',
        ),
        const SizedBox(height: 16),
        FingerprintPanel(fingerprint, large: true),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: fingerprint));
          if (ctx.mounted) {
            ScaffoldMessenger.of(
              ctx,
            ).showSnackBar(const SnackBar(content: Text('Fingerprint copied')));
          }
        },
        child: const Text('Copy'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);

Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

String statusLabel(String status) => switch (status) {
  'active' => 'Active',
  'pending' => 'Pending approval',
  _ => 'Retired',
};
