import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'package:letter_signing/letters/create_letter_screen.dart';
import 'package:letter_signing/letters/letter_crypto_service.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/sign_screen.dart';

/// Decrypts on open (after unlock), shows participants, signatures, thread, attachments; live-updating.
class LetterDetailScreen extends StatefulWidget {
  const LetterDetailScreen({
    super.key,
    required this.env,
    required this.letterId,
  });
  final LettersEnv env;
  final String letterId;

  @override
  State<LetterDetailScreen> createState() => _LetterDetailScreenState();
}

class _LetterDetailScreenState extends State<LetterDetailScreen> {
  LetterDetail? _letter;
  DecryptedLetter? _plain;
  Object? _error;
  String? _decryptError;
  final Set<int> _openedBy = {};
  StreamSubscription<dynamic>? _sub;

  LettersEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    _sub = env.live.events.listen((e) {
      if (!mounted || e.letterId != widget.letterId) return;
      if (e.kind == 'opened' && e.actorId != null)
        setState(() => _openedBy.add(e.actorId!));
      unawaited(_reload());
    });
    unawaited(_start());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final l = await env.api.detail(widget.letterId);
      if (mounted) setState(() => _letter = l);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _start() async {
    await _reload();
    final letter = _letter;
    if (letter == null || !mounted) return;
    if (letter.signers.any((p) => p.userId == env.userId)) {
      unawaited(env.api.markOpened(letter.id).catchError((Object _) {}));
    }
    await _decrypt();
  }

  Future<void> _decrypt() async {
    final letter = _letter;
    if (letter == null) return;
    try {
      final key = await env.vault.unlock(
        context,
        reason: 'Open letter: ${letter.title}',
      );
      if (key == null) throw const LetterException('Key not unlocked');
      final plain = await env.crypto.open(letter, key);
      if (mounted)
        setState(() {
          _plain = plain;
          _decryptError = null;
        });
      unawaited(env.rewrap.run(key).then((_) {}, onError: (Object _) {}));
    } on Object catch (e) {
      if (mounted) setState(() => _decryptError = '$e');
    }
  }

  bool get _isCreator => _letter?.brief.creatorId == env.userId;

  /// This user may sign now (pending signer, and first pending in serial order).
  bool get _myTurn {
    final l = _letter;
    if (l == null || l.status != LetterStatus.inSigning) return false;
    final pending = l.signers.where((p) => p.decision.isEmpty).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    if (pending.isEmpty) return false;
    final eligible = l.order == 'serial' ? [pending.first] : pending;
    return eligible.any((p) => p.userId == env.userId);
  }

  Future<void> _act(Future<Object?> Function() run) async {
    try {
      await run();
      await _reload();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _send() => _act(() async {
    final needsKey = _plain == null
        ? await env.vault.unlock(context, reason: 'Send letter')
        : null;
    return env.crypto.send(
      widget.letterId,
      docKey: _plain?.docKey,
      key: needsKey,
    );
  });

  Future<void> _sign() async {
    final l = _letter!;
    final brief = await Navigator.of(context).push<LetterBrief>(
      MaterialPageRoute(
        builder: (_) => SignScreen(env: env, letter: l),
      ),
    );
    if (brief != null) await _reload();
  }

  Future<void> _certificate() async {
    try {
      final cert = await env.api.certificate(widget.letterId);
      if (!mounted) return;
      final sigs = (cert['signatures'] as List).cast<Map<String, dynamic>>();
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            cert['all_verified'] == true
                ? 'Signatures verified'
                : 'Verification FAILED',
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in sigs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${s['signer']}: ${s['decision']}\nkey ${s['fingerprint']}\n'
                      'device ${s['device']}\n${s['signed_at']}\n${s['verified'] == true ? 'valid' : 'INVALID'}',
                    ),
                  ),
                if (sigs.isEmpty) const Text('No signatures yet'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _attachment(AttachmentInfo info) async {
    final plain = _plain;
    if (plain == null) return;
    try {
      final bytes = await env.crypto.downloadAttachment(
        widget.letterId,
        info,
        plain.docKey,
      );
      final i = int.tryParse(info.label) ?? -1;
      final name = i >= 0 && i < plain.attachments.length
          ? plain.attachments[i].name
          : 'attachment';
      if (!mounted) return;
      if (info.contentType.startsWith('image/') &&
          info.contentType != 'image/heic') {
        await showDialog<void>(
          context: context,
          builder: (_) =>
              Dialog(child: InteractiveViewer(child: Image.memory(bytes))),
        );
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, name: name, mimeType: info.contentType),
          ],
          fileNameOverrides: [name],
        ),
      );
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _letter;
    if (l == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: _error != null
              ? Text('$_error')
              : const CircularProgressIndicator(),
        ),
      );
    }
    final plain = _plain;
    return Scaffold(
      appBar: AppBar(
        title: Text('#${l.brief.no}'),
        actions: [
          IconButton(
            tooltip: 'Certificate',
            icon: const Icon(Icons.verified_outlined),
            onPressed: _certificate,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.title, style: Theme.of(context).textTheme.titleLarge),
            Row(
              children: [
                StatusChip(l.status),
                const SizedBox(width: 8),
                Text(l.brief.visibility),
              ],
            ),
            const Divider(),
            if (plain != null) ...[
              SelectableText(plain.text),
              for (final info in l.attachments)
                ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: Text(_attachmentName(plain, info)),
                  subtitle: Text('${(info.size / 1024).ceil()} KB'),
                  onTap: () => _attachment(info),
                ),
            ] else if (_decryptError != null) ...[
              Text(
                _decryptError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: _decrypt,
                child: const Text('Unlock and retry'),
              ),
            ] else
              const Center(child: CircularProgressIndicator()),
            const Divider(),
            Text(
              'Signers (${l.order == 'serial' ? 'in order' : 'parallel'})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final p in l.signers)
              ListTile(
                dense: true,
                title: Text(p.displayName),
                subtitle: Text(
                  _openedBy.contains(p.userId) && p.decision.isEmpty
                      ? 'opened'
                      : _decisionLabel(p.decision),
                ),
                leading: Icon(switch (p.decision) {
                  'approved' => Icons.check_circle,
                  'rejected' => Icons.cancel,
                  _ => Icons.hourglass_empty,
                }),
              ),
            if (l.viewers.isNotEmpty)
              Text(
                'Viewers: ${[for (final v in l.viewers) v.displayName].join(', ')}',
              ),
            if (l.signatures.isNotEmpty) ...[
              const Divider(),
              Text(
                'Signatures',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final s in l.signatures)
                ListTile(
                  dense: true,
                  title: Text('${s.decision}  ${s.note}'),
                  subtitle: Text(
                    'key ${s.fingerprint}\ndevice ${s.deviceName}\n${s.createdAt.toLocal()}',
                  ),
                  isThreeLine: true,
                ),
            ],
            if (l.children.isNotEmpty) ...[
              const Divider(),
              Text(
                'Chained letters',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final c in l.children)
                ListTile(
                  dense: true,
                  title: Text('#${c.no}  ${c.title}'),
                  trailing: StatusChip(c.status),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          LetterDetailScreen(env: env, letterId: c.id),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                if (_myTurn)
                  FilledButton(
                    onPressed: _sign,
                    child: const Text('Approve / reject'),
                  ),
                if (_isCreator && l.status == LetterStatus.draft)
                  FilledButton(onPressed: _send, child: const Text('Send')),
                if (_isCreator &&
                    (l.status == LetterStatus.draft ||
                        l.status == LetterStatus.inSigning))
                  OutlinedButton(
                    onPressed: () => _act(() => env.api.cancel(l.id)),
                    child: const Text('Cancel letter'),
                  ),
                if (_isCreator &&
                    l.status != LetterStatus.draft &&
                    l.status != LetterStatus.cancelled)
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CreateLetterScreen(env: env, parentId: l.id),
                      ),
                    ),
                    child: const Text('Reply with chained letter'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _attachmentName(DecryptedLetter plain, AttachmentInfo info) {
    final i = int.tryParse(info.label) ?? -1;
    return i >= 0 && i < plain.attachments.length
        ? plain.attachments[i].name
        : 'attachment';
  }

  static String _decisionLabel(String d) => switch (d) {
    'approved' => 'Approved',
    'rejected' => 'Rejected',
    _ => 'Pending',
  };
}
