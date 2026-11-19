import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/notes/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';

/// The 16 pastel note colours; index 0 is the neutral card colour (null).
const List<Color?> noteColors = [
  null,
  Color(0xFFF8D7DA),
  Color(0xFFFFE0B2),
  Color(0xFFFFF3C4),
  Color(0xFFE6EE9C),
  Color(0xFFC8E6C9),
  Color(0xFFB2DFDB),
  Color(0xFFB2EBF2),
  Color(0xFFBBDEFB),
  Color(0xFFC5CAE9),
  Color(0xFFD1C4E9),
  Color(0xFFF8BBD0),
  Color(0xFFD7CCC8),
  Color(0xFFCFD8DC),
  Color(0xFFFFCCBC),
  Color(0xFFDCEDC8),
];

const _ink = Color(0xFF1B1F27);
const _maxShownItems = 5;

/// The background of a note colour (the theme card colour for index 0).
Color noteBackground(BuildContext context, int index) =>
    noteColors[index.clamp(0, noteColors.length - 1)] ??
    Theme.of(context).colorScheme.surfaceContainerHigh;

/// One note as a coloured card: title, text snippet, the first checklist lines, labels.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.labels,
    required this.onTap,
    this.onPin,
  });

  final NoteOut note;
  final List<LabelInfo> labels;
  final VoidCallback onTap;
  final VoidCallback? onPin;

  @override
  Widget build(BuildContext context) {
    final colored = note.color != 0;
    final text = Theme.of(context).textTheme;
    final style = colored ? text.bodyMedium?.copyWith(color: _ink) : null;
    return Card(
      color: noteBackground(context, note.color),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, style, colored),
              if (note.body.isNotEmpty)
                Text(
                  note.body,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ..._items(style),
              _footer(context, style),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, TextStyle? style, bool colored) {
    if (note.title.isEmpty && !note.pinned) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: Text(
            note.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (note.pinned)
          Icon(
            Icons.push_pin,
            size: 16,
            color: colored ? _ink : Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }

  List<Widget> _items(TextStyle? style) => [
    for (final i in note.items.take(_maxShownItems))
      Row(
        children: [
          Icon(
            i.done ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color: style?.color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              i.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style?.copyWith(
                decoration: i.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    if (note.items.length > _maxShownItems)
      Text(
        '+${toPersianDigits(note.items.length - _maxShownItems)}',
        style: style,
      ),
  ];

  Widget _footer(BuildContext context, TextStyle? style) {
    final chosen = [
      for (final l in labels)
        if (note.labelIds.contains(l.id)) l,
    ];
    if (chosen.isEmpty && note.imageCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final l in chosen)
            Text(
              l.name,
              style: style?.copyWith(
                fontSize: 11.5,
                color: style.color ?? labelColor(l.color),
              ),
            ),
          if (note.imageCount > 0)
            Icon(Icons.image_outlined, size: 16, color: style?.color),
        ],
      ),
    );
  }
}
