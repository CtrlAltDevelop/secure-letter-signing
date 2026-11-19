import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/workspace/models.dart';

/// Multi-select of colleagues: the chosen people as chips plus an "add" chip that opens a
/// searchable sheet. The selection keeps its order (approvers form a chain).
class PeoplePicker extends StatelessWidget {
  const PeoplePicker({
    super.key,
    required this.label,
    required this.directory,
    required this.selectedIds,
    required this.onChanged,
    this.known = const [],
    this.errorText,
  });

  final String label;

  /// Everyone that can be chosen.
  final List<UserRef> directory;
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;

  /// People to name even when absent from [directory] (e.g. already on the task).
  final List<UserRef> known;
  final String? errorText;

  String _name(int id) {
    for (final u in [...directory, ...known]) {
      if (u.id == id) return u.displayName;
    }
    return '#$id';
  }

  Future<void> _add(BuildContext context) async {
    final picked = await showPeoplePickerSheet(
      context,
      title: label,
      directory: _merged(),
      selected: selectedIds,
    );
    if (picked != null) onChanged(picked);
  }

  List<UserRef> _merged() {
    final byId = {
      for (final u in known) u.id: u,
      for (final u in directory) u.id: u,
    };
    return byId.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final id in selectedIds)
              InputChip(
                label: Text(_name(id)),
                visualDensity: VisualDensity.compact,
                deleteButtonTooltipMessage: l.peopleRemove(_name(id)),
                onDeleted: () => onChanged([
                  for (final s in selectedIds)
                    if (s != id) s,
                ]),
              ),
            ActionChip(
              avatar: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: Text(l.peopleAdd),
              visualDensity: VisualDensity.compact,
              onPressed: () => unawaited(_add(context)),
            ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorText!,
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

/// Opens the searchable multi-select sheet; resolves to the new selection, or null when
/// dismissed.
Future<List<int>?> showPeoplePickerSheet(
  BuildContext context, {
  required String title,
  required List<UserRef> directory,
  required List<int> selected,
}) => showModalBottomSheet<List<int>>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _PeopleSheet(title: title, directory: directory, selected: selected),
);

class _PeopleSheet extends StatefulWidget {
  const _PeopleSheet({
    required this.title,
    required this.directory,
    required this.selected,
  });

  final String title;
  final List<UserRef> directory;
  final List<int> selected;

  @override
  State<_PeopleSheet> createState() => _PeopleSheetState();
}

class _PeopleSheetState extends State<_PeopleSheet> {
  late List<int> _chosen = [...widget.selected];
  String _query = '';

  bool _matches(UserRef u) {
    final q = _query.trim().toLowerCase();
    return q.isEmpty ||
        u.fullName.toLowerCase().contains(q) ||
        u.email.toLowerCase().contains(q);
  }

  void _toggle(int id, {required bool on}) {
    setState(() {
      _chosen = on
          ? [..._chosen, id]
          : [
              for (final c in _chosen)
                if (c != id) c,
            ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = widget.directory.where(_matches).toList();
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l.peopleSearch,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Flexible(
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l.peopleEmpty),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final u in rows)
                            CheckboxListTile(
                              dense: true,
                              value: _chosen.contains(u.id),
                              title: Text(u.displayName),
                              subtitle: u.fullName.isEmpty
                                  ? null
                                  : Text(u.email),
                              onChanged: (on) => _toggle(u.id, on: on ?? false),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _chosen),
                    child: Text(l.commonConfirm),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
