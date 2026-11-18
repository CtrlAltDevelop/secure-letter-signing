import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/sign_payload.dart';

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
      if (key == null)
        throw const ApiException(0, 'Signing cancelled: key not unlocked');
      final sessionId = env.sessionId;
      if (sessionId == null)
        throw const ApiException(0, 'No session id; sign in again');
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sign')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.letter.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'approved',
              label: Text('Approve'),
              icon: Icon(Icons.check),
            ),
            ButtonSegment(
              value: 'rejected',
              label: Text('Reject'),
              icon: Icon(Icons.close),
            ),
          ],
          selected: {_decision},
          onSelectionChanged: (s) => setState(() => _decision = s.first),
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
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Signing...' : 'Unlock key and sign'),
        ),
      ],
    ),
  );
}
