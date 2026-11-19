import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Registers a new entry, or edits [entry]. Pops the saved [SecretariatEntry].
class SecretariatFormScreen extends StatefulWidget {
  const SecretariatFormScreen({super.key, required this.env, this.entry});
  final LettersEnv env;
  final SecretariatEntry? entry;

  @override
  State<SecretariatFormScreen> createState() => _SecretariatFormState();
}

class _SecretariatFormState extends State<SecretariatFormScreen> {
  late String _direction = widget.entry?.direction ?? SecretariatEntry.incoming;
  late final _title = TextEditingController(text: widget.entry?.title);
  late final _party = TextEditingController(text: widget.entry?.partyName);
  late final _ref = TextEditingController(text: widget.entry?.partyRef);
  late final _summary = TextEditingController(text: widget.entry?.summary);
  LetterBrief? _letter;
  bool _submitted = false;
  bool _saving = false;

  bool get _editing => widget.entry != null;
  LettersEnv get env => widget.env;

  @override
  void dispose() {
    _title.dispose();
    _party.dispose();
    _ref.dispose();
    _summary.dispose();
    super.dispose();
  }

  Future<void> _pickLetter() async {
    final picked = await showModalBottomSheet<LetterBrief>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LetterPicker(env: env),
    );
    if (picked != null && mounted) {
      setState(() {
        _letter = picked;
        if (_title.text.trim().isEmpty) _title.text = picked.title;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final entry = widget.entry;
      final saved = entry == null
          ? await env.v2.register(
              direction: _direction,
              title: _title.text.trim(),
              partyName: _party.text.trim(),
              partyRef: _ref.text.trim(),
              letterId: _direction == SecretariatEntry.outgoing
                  ? _letter?.id
                  : null,
              summary: _summary.text.trim(),
            )
          : await env.v2.patchEntry(
              entry.id,
              title: _title.text.trim(),
              partyName: _party.text.trim(),
              partyRef: _ref.text.trim(),
              summary: _summary.text.trim(),
            );
      if (mounted) Navigator.of(context).pop(saved);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showError(context, e);
    }
  }

  Widget _directionPicker(AppLocalizations l) => SegmentedButton<String>(
    showSelectedIcon: false,
    segments: [
      ButtonSegment(
        value: SecretariatEntry.incoming,
        label: Text(l.secretariatIn),
      ),
      ButtonSegment(
        value: SecretariatEntry.outgoing,
        label: Text(l.secretariatOut),
      ),
    ],
    selected: {_direction},
    onSelectionChanged: _editing
        ? null
        : (v) => setState(() {
            _direction = v.first;
            if (_direction == SecretariatEntry.incoming) _letter = null;
          }),
  );

  Widget _letterField(AppLocalizations l) => OutlinedButton.icon(
    onPressed: _editing ? null : () => unawaited(_pickLetter()),
    icon: const Icon(Icons.mail_outline),
    label: Text(_letter?.title ?? l.secretariatPickLetter),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final outgoing = _direction == SecretariatEntry.outgoing;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l.secretariatEdit : l.secretariatRegister),
      ),
      body: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _directionPicker(l),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: l.secretariatTitle,
                    errorText: _submitted && _title.text.trim().isEmpty
                        ? l.secretariatTitleRequired
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _party,
                  decoration: InputDecoration(
                    labelText: outgoing
                        ? l.secretariatPartyTo
                        : l.secretariatPartyFrom,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ref,
                  decoration: InputDecoration(labelText: l.secretariatPartyRef),
                ),
                if (outgoing) ...[const SizedBox(height: 12), _letterField(l)],
                const SizedBox(height: 12),
                TextField(
                  controller: _summary,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l.secretariatSummary,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : () => unawaited(_save()),
                  child: Text(l.commonSave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterPicker extends StatefulWidget {
  const _LetterPicker({required this.env});
  final LettersEnv env;

  @override
  State<_LetterPicker> createState() => _LetterPickerState();
}

class _LetterPickerState extends State<_LetterPicker> {
  List<LetterBrief>? _rows;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  Future<void> _search(String q) async {
    try {
      final rows = await widget.env.api.list(q: q, limit: 50);
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final r in rows)
            if (r.status == LetterStatus.published) r,
        ];
      });
    } on Object {
      if (mounted) setState(() => _rows = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = _rows;
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
                    hintText: l.lettersSearchHint,
                  ),
                  onChanged: (v) => unawaited(_search(v.trim())),
                ),
              ),
              Flexible(
                child: rows == null
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final r in rows)
                            ListTile(
                              dense: true,
                              title: Text(
                                r.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.of(context).pop(r),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
