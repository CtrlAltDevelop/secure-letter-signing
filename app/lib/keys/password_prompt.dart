import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/crypto/crypto_primitives.dart';
import 'package:letter_signing/keys/key_models.dart';

/// Reusable key-password dialog. [verify] is the check (e.g. `store.unlockWithPassword`): it
/// returns the result on success and throws [WrongPasswordException] / [KeyLockedException] /
/// [KeyException] otherwise; the dialog stays open and shows the error so the user can retry.
/// Returns [verify]'s result, or null if the user cancelled.
Future<T?> showPasswordPrompt<T>(
  BuildContext context, {
  required String title,
  String? reason,
  required Future<T> Function(String password) verify,
}) => showDialog<T>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _PasswordPrompt<T>(title: title, reason: reason, verify: verify),
);

class _PasswordPrompt<T> extends StatefulWidget {
  const _PasswordPrompt({
    required this.title,
    required this.reason,
    required this.verify,
  });
  final String title;
  final String? reason;
  final Future<T> Function(String) verify;

  @override
  State<_PasswordPrompt<T>> createState() => _PasswordPromptState<T>();
}

class _PasswordPromptState<T> extends State<_PasswordPrompt<T>> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _controller.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.verify(_controller.text);
      if (mounted) Navigator.of(context).pop(result);
      return;
    } on WrongPasswordException {
      _error = 'Wrong password';
    } on KeyException catch (e) {
      _error = e.message;
    }
    if (!mounted) return;
    _controller.clear();
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.reason != null) ...[
          Text(widget.reason!),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _controller,
          obscureText: true,
          autofocus: true,
          enabled: !_busy,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Key password',
            errorText: _error,
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: const Text('Unlock'),
      ),
    ],
  );
}
