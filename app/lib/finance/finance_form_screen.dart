import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/finance/finance_env.dart';
import 'package:letter_signing/finance/finance_ui.dart';
import 'package:letter_signing/finance/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letters_env.dart' show showError;
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/money.dart';
import 'package:letter_signing/workspace/widgets/choice_row.dart';
import 'package:letter_signing/workspace/widgets/jalali_date_field.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';
import 'package:letter_signing/workspace/widgets/label_create_sheet.dart';
import 'package:letter_signing/workspace/widgets/reason_dialog.dart';
import 'package:letter_signing/workspace/widgets/subject_files.dart';

/// Create (when [doc] is null) or edit a finance document; a saved document also shows its
/// files, and offers confirm (pending) and void. [customerId] links a new document to a
/// customer file. Pops with the last saved document (null when nothing was saved).
class FinanceFormScreen extends StatefulWidget {
  const FinanceFormScreen({
    super.key,
    required this.env,
    this.doc,
    this.customerId,
  });
  final FinanceEnv env;
  final FinanceDoc? doc;
  final String? customerId;

  @override
  State<FinanceFormScreen> createState() => _FinanceFormState();
}

class _FinanceFormState extends State<FinanceFormScreen> {
  late FinanceDoc? _doc = widget.doc;
  late String _kind = _doc?.kind ?? FinanceKind.cash;
  late String _direction = _doc?.direction ?? FinanceDirection.receipt;
  late final _amount = TextEditingController(
    text: _doc == null ? '' : '${_doc!.amount}',
  );
  late final _description = TextEditingController(text: _doc?.description);
  late DateTime _date = _doc?.date ?? DateUtils.dateOnly(DateTime.now());
  late DateTime? _due = _doc?.dueDate;
  late Set<int> _labelIds = {...?_doc?.labelIds};
  List<LabelInfo> _labels = const [];
  bool _busy = false;
  bool _submitted = false;

  FinanceEnv get env => widget.env;
  bool get _saved => _doc != null;
  bool get _readOnly => _doc?.isVoid ?? false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLabels());
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadLabels() async {
    final labels = await env.labels();
    if (mounted) setState(() => _labels = labels);
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

  int? get _amountValue {
    final v = parseAmount(_amount.text);
    return v == null || v <= 0 ? null : v;
  }

  bool get _dueMissing => _kind != FinanceKind.cash && _due == null;

  FinanceDraft? _draft() {
    final amount = _amountValue;
    if (amount == null || _dueMissing) return null;
    return FinanceDraft(
      kind: _kind,
      direction: _direction,
      amount: amount,
      date: _date,
      dueDate: _due,
      description: _description.text.trim(),
      customerId: widget.customerId ?? _doc?.customerId,
    );
  }

  Future<void> _save() async {
    if (_busy || _readOnly) return;
    final draft = _draft();
    if (draft == null) {
      setState(() => _submitted = true);
      return;
    }
    setState(() => _busy = true);
    try {
      final current = _doc;
      var saved = current == null
          ? await env.api.create(draft)
          : await env.api.patch(current.id, draft.toPatchJson(current));
      if (!setEquals(_labelIds, saved.labelIds.toSet())) {
        await env.api.workspace.setLabels(saved.subjectId, _labelIds.toList());
        saved = await env.api.get(saved.id);
      }
      if (!mounted) return;
      final created = current == null;
      setState(() {
        _doc = saved;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).financeSaved)),
      );
      if (!created) Navigator.of(context).pop(saved);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  Future<void> _confirm() async {
    final d = _doc;
    if (d == null) return;
    try {
      final next = await env.api.confirm(d.id);
      if (!mounted) return;
      setState(() => _doc = next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).financeConfirmed)),
      );
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _void() async {
    final d = _doc;
    if (d == null) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => ReasonDialog(
        title: AppLocalizations.of(context).financeVoid,
        label: AppLocalizations.of(context).financeVoidReason,
        submit: AppLocalizations.of(context).financeVoidSubmit,
      ),
    );
    if (reason == null || !mounted) return;
    try {
      final next = await env.api.voidDoc(d.id, reason);
      if (mounted) setState(() => _doc = next);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _field(Widget w) =>
      Padding(padding: const EdgeInsets.only(bottom: 14), child: w);

  Widget _choice(
    Map<String, String> options,
    String value,
    void Function(String) on,
  ) => ChoiceRow(
    options: options,
    value: value,
    onChanged: _readOnly ? (_) {} : on,
  );

  List<Widget> _fields(AppLocalizations l) {
    final d = _doc;
    final customer = d?.customerName;
    return [
      if (d != null && d.isVoid)
        Container(
          key: const ValueKey('void-banner'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(l.financeVoidedBanner(d.voidReason)),
        ),
      if (customer != null) Text(l.financeCustomer(customer)),
      Text(l.financeKind, style: Theme.of(context).textTheme.labelLarge),
      _choice(
        {for (final k in FinanceKind.creatable) k: kindLabel(l, k)},
        _kind,
        (k) => setState(() => _kind = k),
      ),
      Text(l.financeDirection, style: Theme.of(context).textTheme.labelLarge),
      _choice(
        {for (final k in FinanceDirection.all) k: directionLabel(l, k)},
        _direction,
        (k) => setState(() => _direction = k),
      ),
      TextField(
        key: const ValueKey('fin-amount'),
        controller: _amount,
        enabled: !_readOnly,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: l.financeAmount,
          errorText: _submitted && _amountValue == null
              ? l.financeAmountInvalid
              : null,
          helperText: _amountValue == null ? null : formatAmount(_amountValue!),
        ),
        onChanged: (_) => setState(() {}),
      ),
      JalaliDateField(
        label: l.financeDate,
        value: _date,
        clearable: false,
        onChanged: (v) => setState(() => _date = v ?? _date),
      ),
      if (_kind != FinanceKind.cash)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JalaliDateField(
              label: l.financeDueDate,
              value: _due,
              onChanged: (v) => setState(() => _due = v),
            ),
            if (_submitted && _dueMissing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.financeDueRequired,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      TextField(
        key: const ValueKey('fin-description'),
        controller: _description,
        enabled: !_readOnly,
        minLines: 2,
        maxLines: 6,
        decoration: InputDecoration(labelText: l.financeDescription),
      ),
      Text(l.moneyLabels, style: Theme.of(context).textTheme.labelLarge),
      LabelChips(
        labels: _labels,
        selected: _labelIds,
        onChanged: _readOnly ? null : (s) => setState(() => _labelIds = s),
        onCreate: _readOnly ? null : () => unawaited(_newLabel()),
      ),
      if (d == null)
        Text(l.financeSaveFirstFiles)
      else
        SubjectFiles(
          api: env.api.workspace,
          live: env.live,
          subjectId: d.subjectId,
          userId: env.userId,
          pickFile: env.pickFile,
          saveFile: env.saveFile,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = _doc;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_doc);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_saved ? l.financeEdit : l.financeNew),
          actions: [
            if (d != null && d.isPending)
              IconButton(
                tooltip: l.financeConfirm,
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () => unawaited(_confirm()),
              ),
            if (d != null && !d.isVoid)
              IconButton(
                tooltip: l.financeVoid,
                icon: const Icon(Icons.block),
                onPressed: () => unawaited(_void()),
              ),
            if (!_readOnly)
              TextButton(
                onPressed: _busy ? null : () => unawaited(_save()),
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
