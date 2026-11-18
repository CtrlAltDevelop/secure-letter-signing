import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/letter_crypto_service.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';

/// Create a letter: title, body, attachments, signers (ordered), viewers, visibility, publish timing, chain.
/// Pops the saved/sent [LetterBrief].
class CreateLetterScreen extends StatefulWidget {
  const CreateLetterScreen({super.key, required this.env, this.parentId});
  final LettersEnv env;
  final String? parentId;

  @override
  State<CreateLetterScreen> createState() => _CreateLetterScreenState();
}

class _CreateLetterScreenState extends State<CreateLetterScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  List<DirectoryUser> _directory = const [];
  final List<int> _signers = [];
  final Set<int> _viewers = {};
  final List<PendingAttachment> _files = [];
  String _visibility = 'private';
  String _publish = 'after_sign';
  String _order = 'parallel';
  bool _busy = false;
  String? _error;
  DraftSaved? _saved;

  LettersEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDirectory());
  }

  @override
  void dispose() {
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
    signerIds: List.of(_signers),
    viewerIds: _viewers.where((v) => !_signers.contains(v)).toList(),
    attachments: List.of(_files),
    visibility: _visibility,
    publishMode: _publish,
    order: _order,
    parentId: widget.parentId,
  );

  Future<DraftSaved> _save() async {
    if (_title.text.trim().isEmpty)
      throw const LetterException('Title is required');
    if (_signers.isEmpty)
      throw const LetterException('Add at least one signer');
    final key = _visibility == 'public'
        ? await env.vault.unlock(context, reason: 'Wrap letter for the company')
        : null;
    final prev = _saved;
    final saved = await env.crypto.saveDraft(
      _input(),
      letterId: prev?.brief.id,
      docKey: prev?.docKey,
      uploaded: prev?.uploaded ?? 0,
      key: key,
    );
    _saved = saved;
    return saved;
  }

  Future<void> _run({required bool send}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await _save();
      final brief = send
          ? await env.crypto.send(saved.brief.id, docKey: saved.docKey)
          : saved.brief;
      if (mounted) {
        if (!send)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Draft saved')));
        if (send) Navigator.of(context).pop(brief);
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.parentId == null ? 'New letter' : 'New chained letter',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _title,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Title (visible in lists)',
          ),
        ),
        TextField(
          controller: _body,
          minLines: 6,
          maxLines: 16,
          decoration: const InputDecoration(
            labelText: 'Body (encrypted)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        for (final (i, f) in _files.indexed)
          ListTile(
            dense: true,
            leading: const Icon(Icons.attach_file),
            title: Text(f.name),
            subtitle: Text('${(f.bytes.length / 1024).ceil()} KB'),
            trailing: (_saved?.uploaded ?? 0) > i
                ? const Icon(Icons.cloud_done)
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _files.removeAt(i)),
                  ),
          ),
        TextButton.icon(
          onPressed: _pickAttachments,
          icon: const Icon(Icons.add),
          label: const Text('Attach PDF / image (max 25 MB)'),
        ),
        const Divider(),
        Text('Signers', style: Theme.of(context).textTheme.titleMedium),
        if (_signers.isEmpty) const Text('None selected'),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorderItem: (from, to) =>
              setState(() => _signers.insert(to, _signers.removeAt(from))),
          children: [
            for (final (i, id) in _signers.indexed)
              ListTile(
                key: ValueKey(id),
                dense: true,
                leading: Text('${i + 1}'),
                title: Text(_user(id)?.displayName ?? '$id'),
              ),
          ],
        ),
        TextButton(
          onPressed: () => _pickUsers(signers: true),
          child: const Text('Choose signers'),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'parallel', label: Text('Parallel')),
            ButtonSegment(value: 'serial', label: Text('In order')),
          ],
          selected: {_order},
          onSelectionChanged: (s) => setState(() => _order = s.first),
        ),
        const Divider(),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'private', label: Text('Private')),
            ButtonSegment(value: 'public', label: Text('Public')),
          ],
          selected: {_visibility},
          onSelectionChanged: (s) => setState(() => _visibility = s.first),
        ),
        if (_visibility == 'private') ...[
          Text(
            _viewers.isEmpty
                ? 'No extra viewers'
                : 'Viewers: ${[for (final v in _viewers) _user(v)?.displayName ?? '$v'].join(', ')}',
          ),
          TextButton(
            onPressed: () => _pickUsers(signers: false),
            child: const Text('Choose viewers'),
          ),
          const Text(
            'Removing a viewer later cannot revoke what they already decrypted.',
          ),
        ],
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'after_sign',
              label: Text('Publish after all sign'),
            ),
            ButtonSegment(value: 'now', label: Text('Publish now')),
          ],
          selected: {_publish},
          onSelectionChanged: (s) => setState(() => _publish = s.first),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
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
              child: FilledButton(
                onPressed: _busy ? null : () => _run(send: true),
                child: Text(_busy ? 'Working...' : 'Send'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
