import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/sign_payload.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Approve/reject with a note, then a fresh key unlock, sign and submit. Pops the updated [LetterBrief].
class SignScreen extends StatefulWidget {
  const SignScreen({super.key, required this.env, required this.letter});
  final LettersEnv env;
  final LetterDetail letter;

  @override
  State<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends State<SignScreen> {
  String _decision = 'approved';
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final env = widget.env;
      final letter = widget.letter;
      final key = await env.vault.unlock(
        context,
        reason:
            '${_decision == 'approved' ? 'Approve' : 'Reject'}: ${letter.title}',
      );
      if (key == null) {
        throw const ApiException(0, 'Signing cancelled: key not unlocked');
      }
      final sessionId = env.sessionId;
      if (sessionId == null) {
        throw const ApiException(0, 'No session id; sign in again');
      }
      final payload = buildSignPayload(
        letterId: letter.id,
        title: letter.title,
        parentId: letter.brief.parentId,
        body: letter.body,
        decision: _decision,
        note: _note.text.trim(),
        userId: env.userId,
        keyId: key.keyId,
        fingerprint: key.identity.fp,
        sessionId: sessionId,
        deviceName: env.deviceName,
      );
      final brief = await env.api.sign(
        letter.id,
        keyId: key.keyId,
        payload: payload,
        signature: signDecision(payload, key),
      );
      if (mounted) Navigator.of(context).pop(brief);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = widget.letter;
    final signed = l.signers.where((p) => p.decision.isNotEmpty).length;
    final total = l.signers.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign letter')),
      bottomNavigationBar: Material(
        color: scheme.surfaceContainerLow,
        child: SafeArea(
          top: false,
          child: PageBody(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  ErrorBanner(_error!),
                  const SizedBox(height: 10),
                ],
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open_outlined),
                  label: Text(_busy ? 'Signing...' : 'Unlock key and sign'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '#${l.brief.no}',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          StatusChip(l.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$signed of $total signed',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SectionHeader('Your decision'),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ChoiceCard(
                          icon: Icons.check_circle_outline,
                          label: 'Approve',
                          hint: 'I agree with this letter',
                          color: Tokens.ok,
                          selected: _decision == 'approved',
                          onTap: () => setState(() => _decision = 'approved'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ChoiceCard(
                          icon: Icons.cancel_outlined,
                          label: 'Reject',
                          hint: 'I do not agree',
                          color: Tokens.error,
                          selected: _decision == 'rejected',
                          onTap: () => setState(() => _decision = 'rejected'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_decision == 'rejected')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'A rejection is final. The creator can start a new chained letter.',
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  maxLength: 2000,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: scheme.primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Signing needs a fresh unlock of your key every time. '
                          'Your signature is created on this device and cannot be changed afterwards.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : null,
            borderRadius: BorderRadius.circular(Tokens.radius),
            border: Border.all(
              color: selected ? color : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
