import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/workspace/widgets/bookmark_button.dart';
import 'package:letter_signing/workspace/workspace_api.dart';
import 'package:letter_signing/letters/create_letter_screen.dart';
import 'package:letter_signing/letters/letter_card.dart';
import 'package:letter_signing/letters/letter_certificate.dart';
import 'package:letter_signing/letters/letter_detail_parts.dart';
import 'package:letter_signing/letters/letter_referrals_section.dart';
import 'package:letter_signing/letters/letter_service.dart';
import 'package:letter_signing/letters/letter_tasks_section.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/paper_pages.dart';
import 'package:letter_signing/letters/paper_preview.dart';
import 'package:letter_signing/letters/paper_screen.dart';
import 'package:letter_signing/letters/paraph_screen.dart';
import 'package:letter_signing/letters/rich/rich_doc.dart';
import 'package:letter_signing/letters/rich/rich_layout.dart';
import 'package:letter_signing/letters/sign_screen.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/utils/save_bytes.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';

enum _Menu { labels, archive }

/// Shows the letter (decrypted by the server), participants, signatures, paraphs, referrals,
/// linked tasks, thread and attachments; live-updating.
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
  Object? _error;
  List<LabelInfo> _labels = const [];
  final Set<int> _openedBy = {};
  StreamSubscription<dynamic>? _sub;

  LettersEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    _sub = env.live.events.listen((e) {
      if (!mounted) return;
      if (e.isWorkspace && e.raw['module'] == 'letters') {
        unawaited(_reload());
        return;
      }
      if (e.letterId != widget.letterId) return;
      if (e.kind == 'opened' && e.actorId != null) {
        setState(() => _openedBy.add(e.actorId!));
      }
      unawaited(_reload());
    });
    unawaited(_start());
    unawaited(_loadLabels());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  Future<void> _loadLabels() async {
    final labels = await env.labels();
    if (mounted) setState(() => _labels = labels);
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
  }

  LetterContent get _content =>
      LetterContent.fromBody(_letter?.body ?? const {});

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

  /// Signers, viewers and referees may paraph a letter in signing or published; once each.
  bool get _canParaph {
    final l = _letter;
    if (l == null || _isCreator) return false;
    final live =
        l.status == LetterStatus.inSigning ||
        l.status == LetterStatus.published;
    return live && !l.paraphs.any((p) => p.signerId == env.userId);
  }

  Future<void> _act(Future<Object?> Function() run) async {
    try {
      await run();
      await _reload();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _send() => _act(() => env.api.send(widget.letterId));

  Future<void> _sign() async {
    final l = _letter;
    if (l == null) return;
    final brief = await Navigator.of(context).push<LetterBrief>(
      MaterialPageRoute(
        builder: (_) => SignScreen(env: env, letter: l),
      ),
    );
    if (brief != null) await _reload();
  }

  Future<void> _paraph() async {
    final l = _letter;
    if (l == null) return;
    final done = await Navigator.of(context).push<ParaphInfo>(
      MaterialPageRoute(
        builder: (_) => ParaphScreen(env: env, letter: l),
      ),
    );
    if (done != null) await _reload();
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
      if (mounted) await showCertificateDialog(context, cert);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _attachment(AttachmentInfo info) async {
    try {
      final bytes = await env.letters.downloadAttachment(widget.letterId, info);
      final name = _attachmentName(info);
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
      await saveBytes(bytes, name: name, mimeType: info.contentType);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _onMenu(_Menu m) async {
    final l = _letter;
    if (l == null) return;
    switch (m) {
      case _Menu.archive:
        await _act(() => env.v2.archive(l.id, archived: !l.brief.archived));
      case _Menu.labels:
        final subject = l.brief.subjectId;
        if (subject == null) return;
        final picked = await showLetterLabelsSheet(
          context,
          env: env,
          subjectId: subject,
          selected: l.brief.labelIds,
        );
        if (picked != null) await _reload();
    }
  }

  Widget _menuButton(
    LetterDetail l,
    AppLocalizations t,
  ) => PopupMenuButton<_Menu>(
    tooltip: t.lettersMenu,
    onSelected: (m) => unawaited(_onMenu(m)),
    itemBuilder: (_) => [
      if (l.brief.subjectId != null)
        PopupMenuItem(value: _Menu.labels, child: Text(t.lettersEditLabels)),
      PopupMenuItem(
        value: _Menu.archive,
        child: Text(l.brief.archived ? t.lettersUnarchive : t.lettersArchive),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = _letter;
    if (l == null) return _loading(t);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.letterTitle(toPersianDigits(l.brief.no))),
        actions: [
          BookmarkButton(
            api: WorkspaceApi(env.api.client),
            module: 'letters',
            id: l.brief.id,
          ),
          IconButton(
            tooltip: t.paperTooltip,
            icon: const Icon(Icons.description_outlined),
            onPressed: _openPaper,
          ),
          IconButton(
            tooltip: t.certTooltip,
            icon: const Icon(Icons.verified_outlined),
            onPressed: _certificate,
          ),
          _menuButton(l, t),
        ],
      ),
      bottomNavigationBar: _actionBar(l, t),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: Tokens.gap),
          children: [
            PageBody(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.gap),
              child: _body(l, t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loading(AppLocalizations t) => Scaffold(
    appBar: AppBar(),
    body: _error != null
        ? EmptyState(
            icon: Icons.cloud_off_outlined,
            title: t.letterLoadFailed,
            message: '$_error',
            action: OutlinedButton.icon(
              onPressed: () {
                setState(() => _error = null);
                unawaited(_start());
              },
              icon: const Icon(Icons.refresh),
              label: Text(t.commonRetry),
            ),
          )
        : const Center(child: CircularProgressIndicator()),
  );

  Widget _body(LetterDetail l, AppLocalizations t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _header(l, t),
      if (_myTurn) ...[const SizedBox(height: 12), _yourTurnBanner(t)],
      const SizedBox(height: 12),
      _paper(t),
      if (l.attachments.isNotEmpty) ...[
        SectionHeader(
          t.letterAttachments,
          subtitle: t.letterFileCount(toPersianDigits(l.attachments.length)),
        ),
        _attachments(l),
      ],
      SectionHeader(
        t.letterSigning,
        subtitle: l.order == 'serial' ? t.letterSerial : t.letterParallel,
      ),
      _timeline(l, t),
      SectionHeader(t.paraphTitle),
      ParaphList(paraphs: l.paraphs),
      LetterReferralsSection(
        env: env,
        letterId: l.id,
        canRefer:
            l.status != LetterStatus.draft &&
            l.status != LetterStatus.cancelled,
        onChanged: _reload,
      ),
      LetterTasksSection(env: env, letter: l, onChanged: _reload),
      if (l.customerRefs.isNotEmpty) _customers(l, t),
      if (l.viewers.isNotEmpty) ..._viewers(l, t),
      if (l.children.isNotEmpty) ..._children(l, t),
      const SizedBox(height: 24),
    ],
  );

  Widget _customers(LetterDetail l, AppLocalizations t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(t.letterCustomers),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final id in l.customerRefs)
            Chip(
              avatar: const Icon(Icons.business_outlined, size: 18),
              label: Text(id, textDirection: TextDirection.ltr),
            ),
        ],
      ),
    ],
  );

  List<Widget> _viewers(LetterDetail l, AppLocalizations t) => [
    SectionHeader(t.letterViewers),
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
  ];

  List<Widget> _children(LetterDetail l, AppLocalizations t) => [
    SectionHeader(t.letterChained),
    for (final c in l.children)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          onTap: () => _openLetter(c.id),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '#${toPersianDigits(c.no)}  ${c.title}',
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
  ];

  Widget _header(LetterDetail l, AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 13);
    final parent = l.brief.parentId;
    final sent = l.brief.sentAt;
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
              NumberLabelChip(l.brief.numberLabel),
              if (l.brief.unlisted) StatusPill(t.letterUnlisted),
              if (l.brief.archived) StatusPill(t.letterArchived),
              Text(
                l.brief.visibility == 'public'
                    ? t.lettersPublic
                    : t.lettersPrivate,
                style: muted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(l.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            t.letterCreatedSent(
              fmtDateTime(l.brief.createdAt),
              sent == null ? '' : '  -  ${t.letterSent(fmtDateTime(sent))}',
            ),
            style: muted,
          ),
          if (l.brief.labelIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            LabelChips(labels: _labels, selected: l.brief.labelIds.toSet()),
          ],
          if (parent != null) _parentLink(parent, t, scheme),
        ],
      ),
    );
  }

  Widget _parentLink(String parent, AppLocalizations t, ColorScheme scheme) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: InkWell(
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
                    t.letterRepliesTo,
                    style: TextStyle(color: scheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _yourTurnBanner(AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Tokens.radiusSmall),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.draw_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text(t.letterYourTurn)),
        ],
      ),
    );
  }

  PaperDocument _paperDoc(LetterDetail l, Letterhead head, AppLocalizations t) {
    final content = _content;
    final number = l.brief.numberLabel.isEmpty
        ? '#${toPersianDigits(l.brief.no)}'
        : toPersianDigits(l.brief.numberLabel);
    return PaperDocument(
      head: head,
      title: l.title,
      number: number,
      date: fmtDateTime(l.brief.sentAt ?? l.brief.createdAt),
      text: RichDoc.fromJson(content.text, content.rich),
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
            date: s.signedAt == null ? '' : fmtDateTime(s.signedAt!),
            seal: s.seal,
            documentId: s.contentHash,
          ),
      ],
      paraphs: [
        for (final p in l.paraphs)
          PaperParaph(
            name: p.signerName,
            method: methodLabel(t, p.method),
            date: p.paraphedAt == null ? '' : fmtDateTime(p.paraphedAt!),
          ),
      ],
    );
  }

  Future<void> _openPaper() async {
    final l = _letter;
    if (l == null) return;
    final t = AppLocalizations.of(context);
    var head = const Letterhead();
    try {
      head = await env.api.letterhead();
    } on Object catch (_) {
      // Printing still works without a letterhead.
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PaperScreen(doc: _paperDoc(l, head, t)),
      ),
    );
  }

  Widget _paper(AppLocalizations t) {
    final content = _content;
    final doc = RichDoc.fromJson(content.text, content.rich);
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: content.text.isEmpty
          ? Text(t.letterNoText)
          : SelectableText.rich(
              editorSpan(doc, 16, Theme.of(context).textTheme.bodyLarge),
            ),
    );
  }

  Widget _attachments(LetterDetail l) {
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
                _attachmentName(info),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(fmtSize(info.size)),
              trailing: const Icon(Icons.download_outlined),
              onTap: () => _attachment(info),
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

  Widget _timeline(LetterDetail l, AppLocalizations t) {
    final signers = l.signers.toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    if (signers.isEmpty) return AppCard(child: Text(t.letterNoSigners));
    return AppCard(
      child: Column(
        children: [
          for (final (i, p) in signers.indexed)
            TimelineStep(
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

  Widget? _actionBar(LetterDetail l, AppLocalizations t) {
    final canUnlist = env.isManager && l.status == LetterStatus.published;
    final canSend = _isCreator && l.status == LetterStatus.draft;
    final canCancel =
        _isCreator &&
        (l.status == LetterStatus.draft || l.status == LetterStatus.inSigning);
    final canReply =
        _isCreator &&
        l.status != LetterStatus.draft &&
        l.status != LetterStatus.cancelled;
    if (!(_myTurn ||
        canSend ||
        canCancel ||
        canReply ||
        canUnlist ||
        _canParaph)) {
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
                  label: Text(
                    l.brief.unlisted ? t.letterRelist : t.letterUnlist,
                  ),
                ),
              if (canCancel)
                OutlinedButton(
                  onPressed: () => _act(() => env.api.cancel(l.id)),
                  child: Text(t.letterCancel),
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
                  label: Text(t.letterReply),
                ),
              if (_canParaph)
                OutlinedButton.icon(
                  onPressed: _paraph,
                  icon: const Icon(Icons.border_color_outlined),
                  label: Text(t.paraphAction),
                ),
              if (canSend)
                FilledButton.icon(
                  onPressed: _send,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(t.letterSend),
                ),
              if (_myTurn)
                FilledButton.icon(
                  onPressed: _sign,
                  icon: const Icon(Icons.draw_outlined),
                  label: Text(t.letterSign),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _attachmentName(AttachmentInfo info) {
    final files = _content.attachments;
    final i = int.tryParse(info.label) ?? -1;
    return i >= 0 && i < files.length
        ? files[i].name
        : AppLocalizations.of(context).letterAttachmentFallback;
  }
}
