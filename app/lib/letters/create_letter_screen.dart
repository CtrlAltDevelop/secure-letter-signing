import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/letter_service.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/paper_editor_screen.dart';
import 'package:letter_signing/letters/rich/rich_doc.dart';
import 'package:letter_signing/letters/rich/rich_layout.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

const Duration _autosaveEvery = Duration(seconds: 60);

/// Create a letter: title, body, attachments, signers (ordered), viewers, visibility, publish timing, chain.
/// Pops the saved/sent [LetterBrief].
class CreateLetterScreen extends StatefulWidget {
  const CreateLetterScreen({
    super.key,
    required this.env,
    this.parentId,
    this.autosaveEvery = _autosaveEvery,
  });
  final LettersEnv env;
  final String? parentId;
  final Duration autosaveEvery;

  @override
  State<CreateLetterScreen> createState() => _CreateLetterScreenState();
}

class _CreateLetterScreenState extends State<CreateLetterScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  /// Set when the letter was written in the A4 editor with formatting; the plain box is then read-only.
  RichDoc? _rich;
  List<DirectoryUser> _directory = const [];
  final List<int> _signers = [];
  final Set<int> _viewers = {};
  final List<PendingAttachment> _files = [];
  String _visibility = 'private';
  String _publish = 'after_sign';
  String _order = 'parallel';
  bool _busy = false;
  bool _submitted = false;
  String? _error;
  DraftSaved? _saved;
  Timer? _autosave;
  String _lastSavedState = '';
  String? _autosavedAt;

  LettersEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDirectory());
    _autosave = Timer.periodic(
      widget.autosaveEvery,
      (_) => unawaited(_autosaveDraft()),
    );
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory() async {
    try {
      final d = await env.api.directory();
      if (mounted) setState(() => _directory = d);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  DirectoryUser? _user(int id) =>
      _directory.where((u) => u.id == id).firstOrNull;

  Future<void> _pickAttachments() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'heic'],
    );
    final added = <PendingAttachment>[];
    for (final f in res) {
      final type = mimeFor(f.name);
      if (type == null) continue;
      added.add(
        PendingAttachment(
          name: f.name,
          type: type,
          bytes: await f.readAsBytes(),
        ),
      );
    }
    if (mounted) setState(() => _files.addAll(added));
  }

  static String? mimeFor(String name) =>
      switch (name.split('.').last.toLowerCase()) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => null,
      };

  Future<void> _pickUsers({required bool signers}) async {
    final selected = signers ? {..._signers} : {..._viewers};
    final candidates = _directory
        .where(
          (u) =>
              u.id != env.userId &&
              (!signers ? !_signers.contains(u.id) : u.canSign),
        )
        .toList();
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(signers ? 'Signers' : 'Viewers'),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (candidates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      signers
                          ? 'Nobody to choose yet. A signer must be another user who has the '
                                'letter.sign permission (set by the manager).'
                          : 'Nobody to choose yet. Viewers must be other colleagues.',
                    ),
                  ),
                for (final u in candidates)
                  CheckboxListTile(
                    value: selected.contains(u.id),
                    title: Text(u.displayName),
                    subtitle: Text(u.email),
                    onChanged: (v) => set(
                      () => v == true
                          ? selected.add(u.id)
                          : selected.remove(u.id),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      if (signers) {
        _signers
          ..removeWhere((id) => !result.contains(id))
          ..addAll(result.where((id) => !_signers.contains(id)));
      } else {
        _viewers
          ..clear()
          ..addAll(result);
      }
    });
  }

  DraftInput _input() => DraftInput(
    title: _title.text,
    text: _body.text,
    rich: _rich?.toJson(),
    signerIds: List.of(_signers),
    viewerIds: _viewers.where((v) => !_signers.contains(v)).toList(),
    attachments: List.of(_files),
    visibility: _visibility,
    publishMode: _publish,
    order: _order,
    parentId: widget.parentId,
  );

  /// Everything that goes into the draft, to tell whether anything changed since the last save.
  String get _state => [
    _title.text,
    _body.text,
    '${_rich?.toJson()}',
    '$_signers',
    '${_viewers.toList()..sort()}',
    '${_files.map((f) => f.name).toList()}',
    _visibility,
    _publish,
    _order,
  ].join('\u0000');

  /// Saves the draft on the server every minute while there is something new, once there is a title and a
  /// signer. Never writes the text to disk.
  Future<void> _autosaveDraft() async {
    if (!mounted ||
        _busy ||
        _title.text.trim().isEmpty ||
        _signers.isEmpty ||
        _state == _lastSavedState) {
      return;
    }
    final snapshot = _state;
    setState(() => _busy = true);
    try {
      await _save();
      _lastSavedState = snapshot;
      if (mounted) {
        final n = DateTime.now();
        setState(
          () => _autosavedAt =
              '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}',
        );
      }
    } on Object catch (_) {
      // Quiet: the next tick retries, and Save draft shows real errors.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<DraftSaved> _save() async {
    if (_title.text.trim().isEmpty) {
      throw const LetterException('Title is required');
    }
    if (_signers.isEmpty) {
      throw const LetterException('Add at least one signer');
    }
    final prev = _saved;
    final saved = await env.letters.saveDraft(
      _input(),
      letterId: prev?.brief.id,
      uploaded: prev?.uploaded ?? 0,
    );
    _saved = saved;
    return saved;
  }

  Future<void> _run({required bool send}) async {
    setState(() {
      _busy = true;
      _error = null;
      _submitted = true;
    });
    try {
      final saved = await _save();
      _lastSavedState = _state;
      final brief = send ? await env.api.send(saved.brief.id) : saved.brief;
      if (mounted) {
        if (send) {
          Navigator.of(context).pop(brief);
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Draft saved')));
        }
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card(String title, String subtitle, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.gap),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );

  Widget _helper(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12.5,
      ),
    ),
  );

  Future<void> _writeOnPaper() async {
    var head = const Letterhead();
    try {
      head = await env.api.letterhead();
    } on Object catch (_) {
      // Writing still works without a letterhead.
    }
    if (!mounted) return;
    final result = await Navigator.of(context).push<RichDoc>(
      MaterialPageRoute(
        builder: (_) => PaperEditorScreen(
          head: head,
          title: _title.text.trim(),
          initial: _rich ?? RichDoc.plain(_body.text),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _body.text = result.text;
      _rich = result.hasFormatting ? result : null;
    });
  }

  Widget _contentCard() => _card(
    'Content',
    'The title is visible in lists. The body is stored encrypted on the server.',
    [
      TextField(
        controller: _title,
        maxLength: 200,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Title',
          errorText: _submitted && _title.text.trim().isEmpty
              ? 'Title is required'
              : null,
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _writeOnPaper,
        icon: const Icon(Icons.description_outlined),
        label: const Text('Write on A4 paper (preview and print)'),
      ),
      const SizedBox(height: 8),
      if (_autosavedAt != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Draft auto-saved at $_autosavedAt',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      if (_rich != null)
        InkWell(
          onTap: _writeOnPaper,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Body (formatted)'),
            child: Text.rich(
              editorSpan(_rich!, 14, Theme.of(context).textTheme.bodyMedium),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
      else
        TextField(
          controller: _body,
          minLines: 6,
          maxLines: 16,
          decoration: const InputDecoration(
            labelText: 'Body',
            alignLabelWithHint: true,
          ),
        ),
    ],
  );

  Widget _attachmentsCard() => _card(
    'Attachments',
    'PDF or image, up to 25 MB each. Files are stored encrypted on the server.',
    [
      for (final (i, f) in _files.indexed)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(attachmentIcon(mimeFor(f.name) ?? '')),
          title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(fmtSize(f.bytes.length)),
          trailing: (_saved?.uploaded ?? 0) > i
              ? const Icon(Icons.cloud_done_outlined, color: Tokens.ok)
              : IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _files.removeAt(i)),
                ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _pickAttachments,
          icon: const Icon(Icons.attach_file),
          label: const Text('Attach PDF / image (max 25 MB)'),
        ),
      ),
    ],
  );

  Widget _signerChips() {
    if (_signers.isEmpty) {
      return Text(
        _submitted ? 'Add at least one signer' : 'No signers chosen yet',
        style: TextStyle(
          color: _submitted
              ? Tokens.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    final serial = _order == 'serial';
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: (from, to) =>
          setState(() => _signers.insert(to, _signers.removeAt(from))),
      children: [
        for (final (i, id) in _signers.indexed)
          ListTile(
            key: ValueKey(id),
            contentPadding: EdgeInsets.zero,
            leading: PersonAvatar(
              serial ? '${i + 1}' : (_user(id)?.displayName ?? '$id'),
              size: 32,
            ),
            title: Text(
              _user(id)?.displayName ?? '$id',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('Signer ${i + 1}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _signers.remove(id)),
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _peopleCard() => _card(
    'People',
    'Who signs this letter and who may read it.',
    [
      Text('Signers', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      _signerChips(),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _pickUsers(signers: true),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Choose signers'),
        ),
      ),
      const SizedBox(height: 16),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'parallel', label: Text('Parallel')),
          ButtonSegment(value: 'serial', label: Text('In order')),
        ],
        selected: {_order},
        onSelectionChanged: (s) => setState(() => _order = s.first),
      ),
      _helper(
        _order == 'serial'
            ? 'Signers sign one after another, top to bottom. Drag to reorder.'
            : 'Every signer can sign at the same time.',
      ),
      const SizedBox(height: 16),
      Text('Visibility', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'private', label: Text('Private')),
          ButtonSegment(value: 'public', label: Text('Public')),
        ],
        selected: {_visibility},
        onSelectionChanged: (s) => setState(() => _visibility = s.first),
      ),
      _helper(
        _visibility == 'public'
            ? 'Everyone in the company can read it once published.'
            : 'Only the creator, signers and chosen viewers can read it.',
      ),
      if (_visibility == 'private') ...[
        const SizedBox(height: 12),
        if (_viewers.isEmpty)
          const Text('No extra viewers')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in _viewers)
                InputChip(
                  label: Text(_user(v)?.displayName ?? '$v'),
                  onDeleted: () => setState(() => _viewers.remove(v)),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _pickUsers(signers: false),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Choose viewers'),
          ),
        ),
      ],
    ],
  );

  Widget _deliveryCard() =>
      _card('Delivery', 'When the letter becomes visible to its audience.', [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'after_sign', label: Text('After all sign')),
            ButtonSegment(value: 'now', label: Text('Right away')),
          ],
          selected: {_publish},
          onSelectionChanged: (s) => setState(() => _publish = s.first),
        ),
        _helper(
          _publish == 'now'
              ? 'Viewers see the letter as soon as it is sent.'
              : 'Viewers see the letter only after every signer has approved.',
        ),
      ]);

  Widget _actionBar() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: PageBody(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _run(send: false),
                      child: const Text('Save draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _run(send: true),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text(_busy ? 'Working...' : 'Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.parentId == null ? 'New letter' : 'New chained letter',
      ),
    ),
    bottomNavigationBar: _actionBar(),
    body: ListView(
      children: [
        PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _contentCard(),
              _attachmentsCard(),
              _peopleCard(),
              _deliveryCard(),
            ],
          ),
        ),
      ],
    ),
  );
}
