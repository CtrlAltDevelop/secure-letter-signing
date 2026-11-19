import 'package:material_ui/material_ui.dart';

/// A row of single-choice chips; [value] '' means "all".
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  /// value -> label, in display order; the key '' is the "all" entry.
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final e in options.entries)
        ChoiceChip(
          label: Text(e.value),
          selected: e.key == value,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => onChanged(e.key),
        ),
    ],
  );
}
