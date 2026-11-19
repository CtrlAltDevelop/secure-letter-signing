import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/notes/models.dart';
import 'package:letter_signing/notes/note_card.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/file_thumb.dart';

/// A row of 16 colour swatches.
class NoteColorPicker extends StatelessWidget {
  const NoteColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < noteColors.length; i++)
          Semantics(
            label: l.noteColorName('${i + 1}'),
            selected: i == selected,
            button: true,
            child: InkWell(
              key: ValueKey('note-color-$i'),
              customBorder: const CircleBorder(),
              onTap: () => onChanged(i),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: noteBackground(context, i),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == selected ? scheme.primary : scheme.outline,
                    width: i == selected ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The checklist of a note: tick, remove, move up/down and add.
class NoteChecklistEditor extends StatefulWidget {
  const NoteChecklistEditor({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onToggle,
    required this.onRemove,
    required this.onMove,
  });

  final List<NoteItem> items;
  final ValueChanged<String> onAdd;
  final ValueChanged<NoteItem> onToggle;
  final ValueChanged<NoteItem> onRemove;

  /// Moves the item at the first index to the second.
  final void Function(int from, int to) onMove;

  @override
  State<NoteChecklistEditor> createState() => _ChecklistState();
}

class _ChecklistState extends State<NoteChecklistEditor> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    widget.onAdd(text);
  }

  Widget _row(AppLocalizations l, int index, NoteItem item) {
    final last = index == widget.items.length - 1;
    return Row(
      key: ValueKey('note-item-${item.id}'),
      children: [
        Checkbox(value: item.done, onChanged: (_) => widget.onToggle(item)),
        Expanded(
          child: Text(
            item.text,
            style: item.done
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
        ),
        IconButton(
          tooltip: l.noteItemUp,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: index == 0 ? null : () => widget.onMove(index, index - 1),
        ),
        IconButton(
          tooltip: l.noteItemDown,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: last ? null : () => widget.onMove(index, index + 1),
        ),
        IconButton(
          tooltip: l.noteItemRemove,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => widget.onRemove(item),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, item) in widget.items.indexed) _row(l, i, item),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('note-item-input'),
                controller: _input,
                decoration: InputDecoration(hintText: l.noteChecklistAddHint),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              tooltip: l.noteChecklistAdd,
              icon: const Icon(Icons.add),
              onPressed: _add,
            ),
          ],
        ),
      ],
    );
  }
}

/// Thumbnails of the images of a note (saved ones are downloaded, pending ones already in
/// memory) with a remove button each and an add button.
class NoteImagesStrip extends StatelessWidget {
  const NoteImagesStrip({
    super.key,
    required this.saved,
    required this.pending,
    required this.download,
    required this.onAdd,
    required this.onRemoveSaved,
    required this.onRemovePending,
  });

  final List<FileInfo> saved;
  final List<Uint8List> pending;
  final Future<Uint8List> Function(FileInfo file) download;
  final VoidCallback onAdd;
  final ValueChanged<FileInfo> onRemoveSaved;
  final ValueChanged<int> onRemovePending;

  Widget _tile(Widget thumb, VoidCallback onRemove, String tooltip) => Stack(
    children: [
      thumb,
      PositionedDirectional(
        top: 0,
        end: 0,
        child: IconButton.filledTonal(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          iconSize: 14,
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in saved)
          KeyedSubtree(
            key: ValueKey('note-image-${f.id}'),
            child: _tile(
              FileThumb(load: () => download(f)),
              () => onRemoveSaved(f),
              l.noteImageRemove,
            ),
          ),
        for (final (i, bytes) in pending.indexed)
          KeyedSubtree(
            key: ValueKey('note-pending-$i'),
            child: _tile(
              FileThumb(load: () => Future.value(bytes)),
              () => onRemovePending(i),
              l.noteImageRemove,
            ),
          ),
        if (saved.length + pending.length < maxNoteImages)
          SizedBox.square(
            dimension: 72,
            child: OutlinedButton(
              onPressed: onAdd,
              child: Tooltip(
                message: l.noteImageAdd,
                child: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ),
          ),
      ],
    );
  }
}
