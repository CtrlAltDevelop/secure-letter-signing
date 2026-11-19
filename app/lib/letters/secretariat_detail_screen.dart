import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_card.dart';
import 'package:letter_signing/letters/letter_detail_screen.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/secretariat_form_screen.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/subject_controller.dart';
import 'package:letter_signing/workspace/widgets/file_list.dart';

/// One secretariat entry: its data, an edit button, the linked letter and the attached files.
class SecretariatDetailScreen extends StatefulWidget {
  const SecretariatDetailScreen({
    super.key,
    required this.env,
    required this.entry,
  });
  final LettersEnv env;
  final SecretariatEntry entry;

  @override
  State<SecretariatDetailScreen> createState() => _DetailState();
}

class _DetailState extends State<SecretariatDetailScreen> {
  late SecretariatEntry _entry = widget.entry;
  late final SubjectController _subject = SubjectController(
    api: widget.env.workspace,
    live: widget.env.live,
    subjectId: widget.entry.subjectId,
  );

  LettersEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    _subject.addListener(_onSubject);
    unawaited(_subject.loadFiles());
  }

  @override
  void dispose() {
    _subject
      ..removeListener(_onSubject)
      ..dispose();
    super.dispose();
  }

  void _onSubject() {
    if (mounted) setState(() {});
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<SecretariatEntry>(
      MaterialPageRoute(
        builder: (_) => SecretariatFormScreen(env: env, entry: _entry),
      ),
    );
    if (saved != null && mounted) setState(() => _entry = saved);
  }

  void _openLetter(String id) => unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LetterDetailScreen(env: env, letterId: id),
      ),
    ),
  );

  void _report(ActionOutcome outcome) {
    if (outcome == ActionOutcome.ok || !mounted) return;
    showError(context, _subject.lastError ?? outcome.name);
  }

  Future<void> _upload() async {
    final picked = await env.pickFile();
    if (picked == null) return;
    _report(
      await _subject.uploadFile(
        name: picked.name,
        bytes: picked.bytes,
        contentType: picked.contentType,
      ),
    );
  }

  Future<void> _download(FileInfo f) async {
    final bytes = await _subject.download(f);
    if (bytes == null) {
      _report(ActionOutcome.failed);
      return;
    }
    await env.saveFile(bytes, name: f.name, mimeType: f.contentType);
  }

  Widget _info(AppLocalizations l) {
    final e = _entry;
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 13);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              NumberLabelChip(e.number),
              StatusPill(
                e.isIncoming ? l.secretariatIn : l.secretariatOut,
                tone: e.isIncoming ? Tone.info : Tone.ok,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(e.title, style: Theme.of(context).textTheme.titleLarge),
          if (e.partyName.isNotEmpty)
            Text(
              '${e.isIncoming ? l.secretariatFrom : l.secretariatTo}: ${e.partyName}',
              style: muted,
            ),
          if (e.partyRef.isNotEmpty)
            Text('${l.secretariatPartyRef}: ${e.partyRef}', style: muted),
          if (e.registeredAt != null)
            Text(
              '${l.secretariatRegisteredBy(e.registeredBy.displayName)}  -  ${fmtDateTime(e.registeredAt!)}',
              style: muted,
            ),
          if (e.summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(e.summary),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final letterId = _entry.letterId;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.secretariatDetailTitle),
        actions: [
          IconButton(
            tooltip: l.secretariatEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
        ],
      ),
      body: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _info(l),
                if (letterId != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openLetter(letterId),
                    icon: const Icon(Icons.mail_outline),
                    label: Text(l.secretariatOpenLetter),
                  ),
                ],
                SectionHeader(l.tabFiles),
                FileList(
                  files: _subject.files,
                  currentUserId: env.userId,
                  onUpload: _upload,
                  onDownload: _download,
                  onDeactivate: (f) async =>
                      _report(await _subject.deactivateFile(f.id)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
