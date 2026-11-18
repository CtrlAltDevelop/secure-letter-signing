import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'package:letter_signing/letters/create_letter_screen.dart';
import 'package:letter_signing/letters/letter_crypto_service.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/paper_pages.dart';
import 'package:letter_signing/letters/paper_preview.dart';
import 'package:letter_signing/letters/paper_screen.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/sign_screen.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

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
      if (e.kind == 'opened' && e.actorId != null) {
        setState(() => _openedBy.add(e.actorId!));
      }
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
      if (mounted) {
        setState(() {
          _plain = plain;
          _decryptError = null;
        });
      }
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

  Future<void> _toggleUnlisted(LetterDetail l) =>
      _act(() => env.api.setUnlisted(l.id, unlisted: !l.brief.unlisted));

  void _openLetter(String id) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LetterDetailScreen(env: env, letterId: id),
        ),
      ),
    );
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
        body: _error != null
            ? EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load the letter',
                message: '$_error',
                action: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _error = null);
                    unawaited(_start());
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Letter #${l.brief.no}'),
        actions: [
          if (_plain != null)
            IconButton(
              tooltip: 'Paper / print',
              icon: const Icon(Icons.description_outlined),
              onPressed: _openPaper,
            ),
          IconButton(
            tooltip: 'Certificate',
            icon: const Icon(Icons.verified_outlined),
            onPressed: _certificate,
          ),
        ],
      ),
      bottomNavigationBar: _actionBar(l),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: Tokens.gap),
          children: [
            PageBody(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.gap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(l),
                  if (_myTurn) ...[
                    const SizedBox(height: 12),
                    _yourTurnBanner(),
                  ],
                  const SizedBox(height: 12),
                  _paper(),
                  if (l.attachments.isNotEmpty) ...[
                    SectionHeader('Attachments', subtitle: _attachSubtitle(l)),
                    _attachments(l),
                  ],
                  SectionHeader(
                    'Signing',
                    subtitle: l.order == 'serial'
                        ? 'Signers sign one after another'
                        : 'Signers can sign in any order',
                  ),
                  _timeline(l),
                  if (l.viewers.isNotEmpty) ...[
                    const SectionHeader('Viewers'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final v in l.viewers)
                          Chip(
                            avatar: PersonAvatar(v.displayName, size: 22),
                            label: Text(v.displayName),
                          ),
                      ],
                    ),
                  ],
                  if (l.children.isNotEmpty) ...[
                    const SectionHeader('Chained letters'),
                    for (final c in l.children)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          onTap: () => _openLetter(c.id),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '#${c.no}  ${c.title}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusChip(c.status),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _attachSubtitle(LetterDetail l) {
    final n = l.attachments.length;
    return '$n file${n == 1 ? '' : 's'}, end-to-end encrypted';
  }

  Widget _header(LetterDetail l) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 13);
    final parent = l.brief.parentId;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(l.status),
              if (l.brief.unlisted)
                const StatusPill('Unlisted', tone: Tone.neutral),
              Text(
                l.brief.visibility == 'public' ? 'Public' : 'Private',
                style: muted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(l.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Created ${fmtDateTime(l.brief.createdAt)}'
            '${l.brief.sentAt == null ? '' : '  -  Sent ${fmtDateTime(l.brief.sentAt!)}'}',
            style: muted,
          ),
          if (parent != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _openLetter(parent),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Replies to an earlier letter',
                        style: TextStyle(color: scheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _yourTurnBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Tokens.radiusSmall),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.draw_outlined),
          SizedBox(width: 10),
          Expanded(child: Text('Your signature is needed on this letter.')),
        ],
      ),
    );
  }

  Future<void> _openPaper() async {
    final l = _letter;
    final plain = _plain;
    if (l == null || plain == null) return;
    var head = const Letterhead();
    try {
      head = await env.api.letterhead();
    } on Object catch (_) {
      // Printing still works without a letterhead.
    }
    if (!mounted) return;
    final doc = PaperDocument(
      head: head,
      title: l.title,
      number: '#${l.brief.no}',
      date: fmtDateTime(l.brief.sentAt ?? l.brief.createdAt),
      text: plain.text,
      signatures: [
        for (final s in l.signatures)
          PaperSignature(
            decision: s.decision,
            note: s.note,
            name:
                l.signers
                    .where((p) => p.userId == s.signerId)
                    .map((p) => p.displayName)
                    .firstOrNull ??
                '',
            date: fmtDateTime(s.createdAt),
            fingerprint: s.fingerprint,
            documentId: '${s.payload['contentHash'] ?? ''}',
          ),
      ],
    );
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => PaperScreen(doc: doc)));
  }

  Widget _paper() {
    final scheme = Theme.of(context).colorScheme;
    final plain = _plain;
    final Widget content;
    if (plain != null) {
      content = SelectableText(
        plain.text.isEmpty ? '(No text)' : plain.text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
      );
    } else if (_decryptError != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErrorBanner(_decryptError!),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _decrypt,
            icon: const Icon(Icons.lock_open),
            label: const Text('Unlock and retry'),
          ),
        ],
      );
    } else {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                plain != null ? Icons.lock_open_outlined : Icons.lock_outline,
                size: 16,
                color: plain != null ? Tokens.ok : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                plain != null ? 'Decrypted on this device' : 'Encrypted',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          content,
        ],
      ),
    );
  }

  Widget _attachments(LetterDetail l) {
    final plain = _plain;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, info) in l.attachments.indexed) ...[
            if (i > 0) const Divider(),
            ListTile(
              leading: Icon(
                attachmentIcon(info.contentType),
                color: scheme.primary,
              ),
              title: Text(
                plain == null ? 'Encrypted file' : _attachmentName(plain, info),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(fmtSize(info.size)),
              trailing: Icon(
                plain == null ? Icons.lock_outline : Icons.download_outlined,
              ),
              onTap: plain == null ? null : () => _attachment(info),
            ),
          ],
        ],
      ),
    );
  }

  Color _decisionColor(String d) => switch (d) {
    'approved' => Tokens.ok,
    'rejected' => Tokens.error,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };

  Widget _timeline(LetterDetail l) {
    final signers = l.signers.toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    if (signers.isEmpty) {
      return const AppCard(child: Text('No signers'));
    }
    return AppCard(
      child: Column(
        children: [
          for (final (i, p) in signers.indexed)
            _TimelineStep(
              participant: p,
              signature: l.signatures
                  .where((s) => s.signerId == p.userId)
                  .firstOrNull,
              opened: _openedBy.contains(p.userId),
              color: _decisionColor(p.decision),
              last: i == signers.length - 1,
            ),
        ],
      ),
    );
  }

  Widget? _actionBar(LetterDetail l) {
    final canUnlist = env.isManager && l.status == LetterStatus.published;
    final canSend = _isCreator && l.status == LetterStatus.draft;
    final canCancel =
        _isCreator &&
        (l.status == LetterStatus.draft || l.status == LetterStatus.inSigning);
    final canReply =
        _isCreator &&
        l.status != LetterStatus.draft &&
        l.status != LetterStatus.cancelled;
    if (!(_myTurn || canSend || canCancel || canReply || canUnlist)) {
      return null;
    }
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: PageBody(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (canUnlist)
                OutlinedButton.icon(
                  onPressed: () => _toggleUnlisted(l),
                  icon: Icon(
                    l.brief.unlisted
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  label: Text(l.brief.unlisted ? 'Relist' : 'Unlist'),
                ),
              if (canCancel)
                OutlinedButton(
                  onPressed: () => _act(() => env.api.cancel(l.id)),
                  child: const Text('Cancel letter'),
                ),
              if (canReply)
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CreateLetterScreen(env: env, parentId: l.id),
                    ),
                  ),
                  icon: const Icon(Icons.reply),
                  label: const Text('Reply with letter'),
                ),
              if (canSend)
                FilledButton.icon(
                  onPressed: _send,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send'),
                ),
              if (_myTurn)
                FilledButton.icon(
                  onPressed: _sign,
                  icon: const Icon(Icons.draw_outlined),
                  label: const Text('Sign'),
                ),
            ],
          ),
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
}

String _decisionLabel(String d) => switch (d) {
  'approved' => 'Approved',
  'rejected' => 'Rejected',
  _ => 'Pending',
};

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.participant,
    required this.signature,
    required this.opened,
    required this.color,
    required this.last,
  });
  final Participant participant;
  final SignatureInfo? signature;
  final bool opened;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final p = participant;
    final sig = signature;
    final when = p.decidedAt ?? sig?.createdAt;
    final tone = switch (p.decision) {
      'approved' => Tone.ok,
      'rejected' => Tone.error,
      _ => opened ? Tone.info : Tone.neutral,
    };
    final fp = sig == null
        ? null
        : (sig.fingerprint.length > 12
              ? sig.fingerprint.substring(0, 12)
              : sig.fingerprint);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                PersonAvatar(p.displayName, color: color),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(
                        opened && p.decision.isEmpty
                            ? 'Opened'
                            : _decisionLabel(p.decision),
                        tone: tone,
                      ),
                    ],
                  ),
                  if (when != null) Text(fmtDateTime(when), style: muted),
                  if (sig != null)
                    Text(
                      [
                        if (sig.deviceName.isNotEmpty) sig.deviceName,
                        if (fp != null) 'key $fp',
                      ].join('  -  '),
                      style: muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (sig != null && sig.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('"${sig.note}"'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
