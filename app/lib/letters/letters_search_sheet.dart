import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/letters_v2_api.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/jalali_date_field.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';

/// Advanced search: text, status, label, number, creator, signer and a Jalali date range.
/// Pops the chosen [LetterSearch] (empty criteria clear the search), or null when dismissed.
Future<LetterSearch?> showLetterSearchSheet(
  BuildContext context, {
  required LetterSearch criteria,
  required List<LabelInfo> labels,
}) => showModalBottomSheet<LetterSearch>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _SearchSheet(criteria: criteria, labels: labels),
);

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.criteria, required this.labels});
  final LetterSearch criteria;
  final List<LabelInfo> labels;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  late LetterSearch _c = widget.criteria;
  late final _q = TextEditingController(text: _c.q);
  late final _number = TextEditingController(text: _c.number);
  late final _creator = TextEditingController(text: _c.creator);
  late final _signer = TextEditingController(text: _c.signer);

  @override
  void dispose() {
    _q.dispose();
    _number.dispose();
    _creator.dispose();
    _signer.dispose();
    super.dispose();
  }

  LetterSearch _result() => _c.copyWith(
    q: _q.text.trim(),
    number: _number.text.trim(),
    creator: _creator.text.trim(),
    signer: _signer.text.trim(),
  );

  void _clear() => Navigator.of(context).pop(LetterSearch(box: _c.box));

  Widget _field(TextEditingController c, String label, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        ),
      );

  Widget _status(AppLocalizations l) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: _c.status,
      decoration: InputDecoration(labelText: l.lettersSearchStatus),
      items: [
        DropdownMenuItem(value: '', child: Text(l.lettersSearchAnyStatus)),
        for (final s in LetterStatus.all)
          DropdownMenuItem(value: s, child: Text(letterStatusLabel(l, s))),
      ],
      onChanged: (v) => setState(() => _c = _c.copyWith(status: v ?? '')),
    ),
  );

  Widget _dates(AppLocalizations l) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: JalaliDateField(
          label: l.lettersSearchFrom,
          value: _c.from,
          onChanged: (d) => setState(
            () => _c = d == null
                ? _c.copyWith(clearFrom: true)
                : _c.copyWith(from: d),
          ),
        ),
      ),
      JalaliDateField(
        label: l.lettersSearchTo,
        value: _c.to,
        onChanged: (d) => setState(
          () =>
              _c = d == null ? _c.copyWith(clearTo: true) : _c.copyWith(to: d),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shrinkWrap: true,
            children: [
              Text(
                l.lettersAdvancedSearch,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _field(_q, l.lettersSearchText, Icons.search),
              _status(l),
              if (widget.labels.isNotEmpty) ...[
                Text(
                  l.lettersSearchLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                LabelChips(
                  labels: widget.labels,
                  selected: {?_c.label},
                  single: true,
                  onChanged: (v) => setState(
                    () => _c = v.isEmpty
                        ? _c.copyWith(clearLabel: true)
                        : _c.copyWith(label: v.first),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _field(_number, l.lettersSearchNumber, Icons.tag),
              _field(_creator, l.lettersSearchCreator, Icons.edit_outlined),
              _field(_signer, l.lettersSearchSigner, Icons.draw_outlined),
              _dates(l),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: _clear,
                    child: Text(l.lettersSearchReset),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_result()),
                    child: Text(l.lettersSearchApply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
