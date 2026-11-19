import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/workspace/models.dart';

const _labelPalette = [
  Color(0xFF8A94A6),
  Color(0xFF4C8DFF),
  Color(0xFF4CD8B9),
  Color(0xFFCFA44B),
  Color(0xFFD65959),
  Color(0xFFA06CD5),
  Color(0xFFE07BB5),
  Color(0xFF5BBAD5),
];

/// The palette colour of a label's `color` index.
Color labelColor(int index) =>
    _labelPalette[index.abs() % _labelPalette.length];

/// Label chips. With [onChanged] they are selectable ([single] keeps at most one selected,
/// for filters); without it only the [selected] labels are shown, read-only.
class LabelChips extends StatelessWidget {
  const LabelChips({
    super.key,
    required this.labels,
    required this.selected,
    this.onChanged,
    this.single = false,
    this.onCreate,
  });

  final List<LabelInfo> labels;
  final Set<int> selected;
  final ValueChanged<Set<int>>? onChanged;
  final bool single;

  /// Adds a trailing "new label" chip (editable chips only) that calls this.
  final VoidCallback? onCreate;

  void _toggle(int id, bool on) {
    if (single) {
      onChanged?.call(on ? {id} : <int>{});
      return;
    }
    onChanged?.call(on ? {...selected, id} : ({...selected}..remove(id)));
  }

  @override
  Widget build(BuildContext context) {
    final editable = onChanged != null;
    final shown = [
      for (final l in labels)
        if (editable || selected.contains(l.id)) l,
    ];
    final create = editable ? onCreate : null;
    if (shown.isEmpty && create == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final l in shown) _chip(l, editable: editable),
        if (create != null)
          Builder(
            builder: (context) => ActionChip(
              key: const ValueKey('label-new'),
              avatar: const Icon(Icons.add, size: 18),
              label: Text(AppLocalizations.of(context).labelNew),
              visualDensity: VisualDensity.compact,
              onPressed: create,
            ),
          ),
      ],
    );
  }

  Widget _chip(LabelInfo l, {required bool editable}) {
    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: labelColor(l.color),
        shape: BoxShape.circle,
      ),
    );
    if (!editable) {
      return Chip(
        avatar: dot,
        label: Text(l.name),
        visualDensity: VisualDensity.compact,
      );
    }
    return FilterChip(
      avatar: dot,
      label: Text(l.name),
      selected: selected.contains(l.id),
      visualDensity: VisualDensity.compact,
      onSelected: (on) => _toggle(l.id, on),
    );
  }
}
