import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/crm/crm_env.dart';
import 'package:letter_signing/crm/crm_ui.dart';
import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/widgets/choice_row.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Create (when [customer] is null) or edit a customer file. Pops the saved [Customer].
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, required this.env, this.customer});
  final CrmEnv env;
  final Customer? customer;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  late CustomerDraft _draft = widget.customer == null
      ? const CustomerDraft()
      : CustomerDraft.fromCustomer(widget.customer!);
  late final _name = TextEditingController(text: _draft.name);
  late final _legal = TextEditingController(text: _draft.legalName);
  late final _nid = TextEditingController(text: _draft.nationalId);
  late final _reg = TextEditingController(text: _draft.registrationNo);
  late final _phone = TextEditingController(text: _draft.phone);
  late final _mobile = TextEditingController(text: _draft.mobile);
  late final _email = TextEditingController(text: _draft.email);
  late final _address = TextEditingController(text: _draft.address);
  late final _notes = TextEditingController(text: _draft.notes);
  bool _submitted = false;
  bool _saving = false;

  bool get _editing => widget.customer != null;

  @override
  void dispose() {
    for (final c in [
      _name,
      _legal,
      _nid,
      _reg,
      _phone,
      _mobile,
      _email,
      _address,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _update(CustomerDraft Function(CustomerDraft) f) =>
      setState(() => _draft = f(_draft));

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _submitted = true);
    if (_draft.nameMissing) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final api = widget.env.api;
      final saved = _editing
          ? await api.patch(
              widget.customer!.id,
              _draft.patchAgainst(widget.customer!),
            )
          : await api.create(_draft);
      nav.pop(saved);
    } on ConflictException {
      messenger.showSnackBar(SnackBar(content: Text(l.crmLimitReached)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l.crmSaveFailed)));
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _field(
    TextEditingController c,
    String label,
    CustomerDraft Function(CustomerDraft, String) apply, {
    TextInputType? type,
    int maxLines = 1,
    String? error,
    bool ltr = false,
  }) => TextField(
    controller: c,
    keyboardType: type,
    maxLines: maxLines,
    textDirection: ltr ? TextDirection.ltr : null,
    decoration: InputDecoration(labelText: label, errorText: error),
    onChanged: (v) => _update((d) => apply(d, v)),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final company = _draft.kind == CustomerKind.company;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l.crmEditTitle : l.crmNew),
        actions: [
          TextButton(
            key: const ValueKey('crm-save'),
            onPressed: _saving ? null : () => unawaited(_save()),
            child: Text(l.commonSave),
          ),
        ],
      ),
      body: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                ChoiceRow(
                  options: {
                    for (final k in CustomerKind.all)
                      k: customerKindLabel(l, k),
                  },
                  value: _draft.kind,
                  onChanged: (v) => _update((d) => d.copyWith(kind: v)),
                ),
                _field(
                  _name,
                  l.crmFieldName,
                  (d, v) => d.copyWith(name: v),
                  error: _submitted && _draft.nameMissing
                      ? l.crmNameRequired
                      : null,
                ),
                if (company) ...[
                  _field(
                    _legal,
                    l.crmFieldLegalName,
                    (d, v) => d.copyWith(legalName: v),
                  ),
                  _field(
                    _reg,
                    l.crmFieldRegistrationNo,
                    (d, v) => d.copyWith(registrationNo: v),
                    ltr: true,
                  ),
                ],
                _field(
                  _nid,
                  l.crmFieldNationalId,
                  (d, v) => d.copyWith(nationalId: v),
                  type: TextInputType.number,
                  ltr: true,
                ),
                _field(
                  _phone,
                  l.crmFieldPhone,
                  (d, v) => d.copyWith(phone: v),
                  type: TextInputType.phone,
                  ltr: true,
                ),
                _field(
                  _mobile,
                  l.crmFieldMobile,
                  (d, v) => d.copyWith(mobile: v),
                  type: TextInputType.phone,
                  ltr: true,
                ),
                _field(
                  _email,
                  l.crmFieldEmail,
                  (d, v) => d.copyWith(email: v),
                  type: TextInputType.emailAddress,
                  ltr: true,
                ),
                _field(
                  _address,
                  l.crmFieldAddress,
                  (d, v) => d.copyWith(address: v),
                  maxLines: 3,
                ),
                _field(
                  _notes,
                  l.crmFieldNotes,
                  (d, v) => d.copyWith(notes: v),
                  maxLines: 5,
                ),
                if (_editing)
                  ChoiceRow(
                    options: {
                      for (final s in CustomerStatus.all)
                        s: customerStatusLabel(l, s),
                    },
                    value: _draft.status,
                    onChanged: (v) => _update((d) => d.copyWith(status: v)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
