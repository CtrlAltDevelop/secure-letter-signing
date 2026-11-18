import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';

/// App-wide host: shows a dialog whenever another device of the user asks this one to approve a signature.
class SignApprovalHost extends StatefulWidget {
  const SignApprovalHost({super.key, required this.env, required this.child});
  final LettersEnv env;
  final Widget child;

  @override
  State<SignApprovalHost> createState() => _SignApprovalHostState();
}

class _SignApprovalHostState extends State<SignApprovalHost> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    widget.env.approvals.addListener(_onChange);
    unawaited(widget.env.approvals.refresh());
  }

  @override
  void dispose() {
    widget.env.approvals.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (_showing || widget.env.approvals.pending.isEmpty) return;
    // After the frame: the listener can fire while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showNext());
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _showNext() async {
    final queue = widget.env.approvals.pending;
    if (_showing || queue.isEmpty) return;
    _showing = true;
    final request = queue.first;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ApprovalDialog(env: widget.env, request: request),
    );
    _showing = false;
    if (mounted) _onChange();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Letter, decision, note and requesting device, with Approve (biometric first) and Decline.
class ApprovalDialog extends StatefulWidget {
  const ApprovalDialog({super.key, required this.env, required this.request});
  final LettersEnv env;
  final SignRequest request;

  @override
  State<ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<ApprovalDialog> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Close by itself when the request is resolved elsewhere (cancelled, expired).
    widget.env.approvals.addListener(_watch);
  }

  @override
  void dispose() {
    widget.env.approvals.removeListener(_watch);
    super.dispose();
  }

  void _watch() {
    final stillPending = widget.env.approvals.pending.any(
      (r) => r.id == widget.request.id,
    );
    if (!stillPending && !_busy && mounted) Navigator.of(context).pop();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final approve = r.decision == 'approved';
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return AlertDialog(
      title: const Text('Approve signature?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.letterTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              approve ? 'Decision: Approve' : 'Decision: Reject',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (r.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Note: "${r.note}"'),
            ],
            const SizedBox(height: 10),
            Text(
              'Requested from ${r.requesterDeviceName.isEmpty ? 'another device' : r.requesterDeviceName}. '
              'Only approve it if that was you.',
              style: muted,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(() => widget.env.approvals.decline(r)),
          child: const Text('Decline'),
        ),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() => widget.env.approvals.approve(r)),
          icon: const Icon(Icons.fingerprint),
          label: const Text('Approve'),
        ),
      ],
    );
  }
}
