import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// The result of the label editor.
typedef LabelEdit = ({String name, int color, String scope});

/// Number of palette colours a label can pick (see [labelColor]).
const labelColorCount = 8;

/// Asks for a label's name and colour (and, for managers creating one, its scope). Resolves to
/// null when cancelled.
Future<LabelEdit?> showLabelEditor(
  BuildContext context, {
  LabelInfo? existing,
  bool canOrg = false,
}) => showDialog<LabelEdit>(
  context: context,
  builder: (_) => _LabelEditor(existing: existing, canOrg: canOrg),
);

/// Creates a personal label (or an organisation one when [canOrg]) after asking for its name
/// and colour. A duplicate name shows a message and resolves to null.
Future<LabelInfo?> showLabelCreateSheet(
  BuildContext context,
  WorkspaceApi api, {
  bool canOrg = false,
}) async {
  final edit = await showLabelEditor(context, canOrg: canOrg);
  if (edit == null || !context.mounted) return null;
  try {
    return await api.createLabel(
      name: edit.name,
      color: edit.color,
      scope: edit.scope,
    );
  } on ConflictException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).labelDuplicate)),
      );
    }
  } on Object catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
  return null;
}

class _LabelEditor extends StatefulWidget {
  const _LabelEditor({required this.canOrg, this.existing});

  final LabelInfo? existing;
  final bool canOrg;

  @override
  State<_LabelEditor> createState() => _LabelEditorState();
}

class _LabelEditorState extends State<_LabelEditor> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late int _color = widget.existing?.color ?? 0;
  String _scope = 'personal';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, color: _color, scope: _scope));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? l.labelEdit : l.labelNew),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('label-name'),
              controller: _name,
              autofocus: true,
              maxLength: 50,
              decoration: InputDecoration(labelText: l.labelName),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (var i = 0; i < labelColorCount; i++)
                  InkResponse(
                    key: ValueKey('label-color-$i'),
                    onTap: () => setState(() => _color = i),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: labelColor(i),
                        shape: BoxShape.circle,
                        border: _color == i
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.canOrg && !editing)
              SwitchListTile(
                key: const ValueKey('label-org'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.labelScopeOrg),
                value: _scope == 'org',
                onChanged: (v) =>
                    setState(() => _scope = v ? 'org' : 'personal'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('label-save'),
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
