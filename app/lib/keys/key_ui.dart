import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/crypto/crypto_primitives.dart';
import 'package:letter_signing/keys/key_models.dart';

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

/// A fingerprint in monospace, selectable so it can be compared or copied.
class FingerprintText extends StatelessWidget {
  const FingerprintText(this.fingerprint, {super.key, this.large = false});
  final String fingerprint;
  final bool large;

  @override
  Widget build(BuildContext context) => SelectableText(
    fingerprint,
    style: TextStyle(
      fontFamily: 'monospace',
      fontSize: large ? 22 : 13,
      letterSpacing: 1,
    ),
  );
}

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
        FingerprintText(fingerprint, large: true),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Clipboard.setData(ClipboardData(text: fingerprint)),
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
  'pending' => 'Pending manager approval',
  _ => 'Retired',
};
