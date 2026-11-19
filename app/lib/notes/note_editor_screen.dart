import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letters_env.dart' show showError;
import 'package:letter_signing/notes/models.dart';
import 'package:letter_signing/notes/note_editor_parts.dart';
import 'package:letter_signing/notes/notes_env.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';
import 'package:letter_signing/workspace/widgets/label_create_sheet.dart';

/// Create (when [note] is null) or edit a note. Checklist changes, pin and images of a saved
/// note are applied at once; title, text, colour and labels are saved when leaving. Pops with
/// the saved [NoteOut] (null when nothing was created).
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.env, this.note});
  final NotesEnv env;
  final NoteOut? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditorScreen> {
  late final _title = TextEditingController(text: widget.note?.title);
  late final _body = TextEditingController(text: widget.note?.body);
  late NoteOut? _note = widget.note;
  late int _color = widget.note?.color ?? 0;
  late bool _pinned = widget.note?.pinned ?? false;
  late List<NoteItem> _items = [...?widget.note?.items];
  late Set<int> _labelIds = {...?widget.note?.labelIds};
  List<LabelInfo> _labels = const [];
  List<FileInfo> _images = const [];
  final List<PickedFile> _pending = [];
  int _localId = 0;
  bool _busy = false;

  NotesEnv get env => widget.env;
  bool get _saved => _note != null;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLookups());
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    final labels = await env.labels();
    var images = <FileInfo>[];
    final note = _note;
    if (note != null) {
      try {
        final files = await env.api.workspace.files(note.subjectId);
        images = [
          for (final f in files)
            if (f.contentType.startsWith('image/')) f,
        ];
      } on Object {
        // Thumbnails are optional.
      }
    }
    if (!mounted) return;
    setState(() {
      _labels = labels;
      _images = images;
    });
  }

  /// Runs a write on the saved note; its result replaces the local state.
  Future<void> _remote(Future<NoteOut> Function(NoteOut note) call) async {
    final note = _note;
    if (note == null) return;
    try {
      final next = await call(note);
      if (!mounted) return;
      setState(() {
        _note = next;
        _items = next.items;
        _pinned = next.pinned;
      });
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _addItem(String text) {
    if (_saved) {
      unawaited(_remote((n) => env.api.addItem(n.id, text)));
    } else {
      setState(
        () => _items = [..._items, NoteItem(id: --_localId, text: text)],
      );
    }
  }

  void _toggleItem(NoteItem item) {
    if (_saved) {
      unawaited(
        _remote((n) => env.api.patchItem(n.id, item.id, done: !item.done)),
      );
    } else {
      setState(() => _items = _replace(item, item.copyWith(done: !item.done)));
    }
  }

  List<NoteItem> _replace(NoteItem from, NoteItem to) => [
    for (final i in _items) i.id == from.id ? to : i,
  ];

  void _removeItem(NoteItem item) {
    if (_saved) {
      unawaited(
        _remote((n) => env.api.patchItem(n.id, item.id, active: false)),
      );
    } else {
      setState(
        () => _items = [
          for (final i in _items)
            if (i.id != item.id) i,
        ],
      );
    }
  }

  void _moveItem(int from, int to) {
    final moved = [..._items];
    moved.insert(to, moved.removeAt(from));
    if (_saved) {
      unawaited(
        _remote((n) => env.api.reorder(n.id, [for (final i in moved) i.id])),
      );
    } else {
      setState(() => _items = moved);
    }
  }

  void _togglePin() {
    if (_saved) {
      unawaited(_remote((n) => env.api.pin(n.id, pinned: !_pinned)));
    } else {
      setState(() => _pinned = !_pinned);
    }
  }

  Future<void> _archive() async {
    final note = _note;
    if (note == null) return;
    await _remote((n) => env.api.archive(n.id, archived: !n.archived));
    if (mounted && _note?.archived != note.archived) {
      Navigator.of(context).pop(_note);
    }
  }

  Future<void> _newLabel() async {
    final label = await showLabelCreateSheet(context, env.api.workspace);
    if (label == null || !mounted) return;
    env.invalidateLabels();
    final labels = await env.labels();
    if (!mounted) return;
    setState(() {
      _labels = labels;
      _labelIds = {..._labelIds, label.id};
    });
  }

  Future<void> _addImage() async {
    final l = AppLocalizations.of(context);
    final picked = await env.pickFile();
    if (picked == null || !mounted) return;
    if (!picked.contentType.startsWith('image/')) {
      showError(context, l.noteImageOnly);
      return;
    }
    final note = _note;
    if (note == null) {
      setState(() => _pending.add(picked));
      return;
    }
    await _upload(note.subjectId, picked);
  }

  Future<void> _upload(String subjectId, PickedFile file) async {
    try {
      final info = await env.api.workspace.uploadFile(
        subjectId,
        name: file.name,
        bytes: file.bytes,
        contentType: file.contentType,
      );
      if (mounted) setState(() => _images = [..._images, info]);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _removeImage(FileInfo f) async {
    try {
      await env.api.workspace.deactivateFile(f.id);
      if (mounted) {
        setState(
          () => _images = [
            for (final i in _images)
              if (i.id != f.id) i,
          ],
        );
      }
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  bool get _blank =>
      _title.text.trim().isEmpty &&
      _body.text.trim().isEmpty &&
      _items.isEmpty &&
      _pending.isEmpty;

  /// Saves what is pending and leaves; stays open (with a message) on failure.
  Future<void> _saveAndClose() async {
    if (_busy) return;
    if (!_saved && _blank) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = _saved ? await _update(_note!) : await _create();
      if (mounted) Navigator.of(context).pop(saved);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  Future<NoteOut> _create() async {
    var note = await env.api.create(
      title: _title.text.trim(),
      body: _body.text,
      color: _color,
      pinned: _pinned,
      checklist: [for (final i in _items) i.text],
    );
    if (_labelIds.isNotEmpty) {
      await env.api.workspace.setLabels(note.subjectId, _labelIds.toList());
    }
    for (final p in _pending) {
      await env.api.workspace.uploadFile(
        note.subjectId,
        name: p.name,
        bytes: p.bytes,
        contentType: p.contentType,
      );
    }
    note = await env.api.get(note.id);
    return note;
  }

  Future<NoteOut> _update(NoteOut note) async {
    var next = note;
    final title = _title.text.trim();
    if (title != note.title ||
        _body.text != note.body ||
        _color != note.color) {
      next = await env.api.patch(
        note.id,
        title: title == note.title ? null : title,
        body: _body.text == note.body ? null : _body.text,
        color: _color == note.color ? null : _color,
      );
    }
    if (!setEquals(_labelIds, note.labelIds.toSet())) {
      await env.api.workspace.setLabels(note.subjectId, _labelIds.toList());
    }
    return next;
  }

  Widget _field(Widget w) =>
      Padding(padding: const EdgeInsets.only(bottom: 14), child: w);

  List<Widget> _fields(AppLocalizations l) => [
    TextField(
      key: const ValueKey('note-title'),
      controller: _title,
      maxLength: 200,
      decoration: InputDecoration(hintText: l.noteTitleHint),
    ),
    TextField(
      key: const ValueKey('note-body'),
      controller: _body,
      minLines: 4,
      maxLines: 14,
      decoration: InputDecoration(hintText: l.noteBodyHint),
    ),
    NoteChecklistEditor(
      items: _items,
      onAdd: _addItem,
      onToggle: _toggleItem,
      onRemove: _removeItem,
      onMove: _moveItem,
    ),
    NoteImagesStrip(
      saved: _images,
      pending: [for (final p in _pending) p.bytes],
      download: (f) => env.api.workspace.downloadFile(f.id),
      onAdd: () => unawaited(_addImage()),
      onRemoveSaved: (f) => unawaited(_removeImage(f)),
      onRemovePending: (i) => setState(() => _pending.removeAt(i)),
    ),
    NoteColorPicker(
      selected: _color,
      onChanged: (c) => setState(() => _color = c),
    ),
    LabelChips(
      labels: _labels,
      selected: _labelIds,
      onChanged: (s) => setState(() => _labelIds = s),
      onCreate: () => unawaited(_newLabel()),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_saveAndClose());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_saved ? l.noteEdit : l.notesNew),
          actions: [
            IconButton(
              tooltip: _pinned ? l.noteUnpin : l.notePin,
              isSelected: _pinned,
              icon: const Icon(Icons.push_pin_outlined),
              selectedIcon: const Icon(Icons.push_pin),
              onPressed: _togglePin,
            ),
            if (_saved)
              IconButton(
                tooltip: _note!.archived ? l.noteUnarchive : l.noteArchive,
                icon: Icon(
                  _note!.archived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                onPressed: () => unawaited(_archive()),
              ),
            TextButton(
              onPressed: _busy ? null : () => unawaited(_saveAndClose()),
              child: Text(l.commonSave),
            ),
          ],
        ),
        body: PageBody(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 48),
            children: [for (final w in _fields(l)) _field(w)],
          ),
        ),
      ),
    );
  }
}
