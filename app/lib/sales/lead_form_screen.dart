import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letters_env.dart' show showError;
import 'package:letter_signing/sales/models.dart';
import 'package:letter_signing/sales/sales_env.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/money.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';
import 'package:letter_signing/workspace/widgets/label_create_sheet.dart';
import 'package:letter_signing/workspace/widgets/reason_dialog.dart';
import 'package:letter_signing/workspace/widgets/subject_files.dart';

const _defaultProbability = 50;

/// Create (when [lead] is null) or edit a lead; a saved lead also shows its files and the
/// win / lose / reopen actions. Only an open lead of the owner or creator is editable.
/// [customerId] links a new lead to a customer file. Pops with the last saved lead.
class LeadFormScreen extends StatefulWidget {
  const LeadFormScreen({
    super.key,
    required this.env,
    this.lead,
    this.customerId,
  });
  final SalesEnv env;
  final Lead? lead;
  final String? customerId;

  @override
  State<LeadFormScreen> createState() => _LeadFormState();
}

class _LeadFormState extends State<LeadFormScreen> {
  late Lead? _lead = widget.lead;
  late final _title = TextEditingController(text: _lead?.title);
  late final _value = TextEditingController(
    text: _lead == null ? '' : '${_lead!.value}',
  );
  late final _description = TextEditingController(text: _lead?.description);
  late double _probability = (_lead?.probability ?? _defaultProbability)
      .toDouble();
  late int? _ownerId = _lead?.owner.id;
  late Set<int> _labelIds = {...?_lead?.labelIds};
  List<LabelInfo> _labels = const [];
  List<UserRef> _people = const [];
  bool _busy = false;
  bool _submitted = false;

  SalesEnv get env => widget.env;
  bool get _saved => _lead != null;
  bool get _readOnly {
    final l = _lead;
    return l != null && (!l.isOpen || !l.canEdit);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadLookups());
  }

  @override
  void dispose() {
    _title.dispose();
    _value.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    final labels = await env.labels();
    final people = await env.directory();
    if (!mounted) return;
    setState(() {
      _labels = labels;
      _people = people;
    });
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

  int? get _valueNumber => parseAmount(_value.text.isEmpty ? '0' : _value.text);

  Future<void> _save() async {
    if (_busy || _readOnly) return;
    final title = _title.text.trim();
    final value = _valueNumber;
    if (title.isEmpty || value == null) {
      setState(() => _submitted = true);
      return;
    }
    final draft = LeadDraft(
      title: title,
      value: value,
      probability: _probability.round(),
      description: _description.text.trim(),
      ownerId: _ownerId,
      customerId: widget.customerId ?? _lead?.customerId,
    );
    setState(() => _busy = true);
    try {
      final current = _lead;
      var saved = current == null
          ? await env.api.create(draft)
          : await env.api.patch(current.id, draft.toPatchJson(current));
      if (!setEquals(_labelIds, saved.labelIds.toSet())) {
        await env.api.workspace.setLabels(saved.subjectId, _labelIds.toList());
        saved = await env.api.get(saved.id);
      }
      if (!mounted) return;
      setState(() {
        _lead = saved;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).salesSaved)),
      );
      if (current != null) Navigator.of(context).pop(saved);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  Future<void> _transition(Future<Lead> Function(Lead l) call) async {
    final l = _lead;
    if (l == null) return;
    try {
      final next = await call(l);
      if (!mounted) return;
      setState(() {
        _lead = next;
        _probability = next.probability.toDouble();
      });
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _lose() async {
    final l = AppLocalizations.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => ReasonDialog(
        title: l.salesLose,
        label: l.salesLoseReason,
        submit: l.salesLoseSubmit,
      ),
    );
    if (reason == null) return;
    await _transition((lead) => env.api.lose(lead.id, reason));
  }

  Widget _field(Widget w) =>
      Padding(padding: const EdgeInsets.only(bottom: 14), child: w);

  Widget _actions(AppLocalizations l, Lead lead) {
    if (!lead.canEdit) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: [
        if (lead.isOpen) ...[
          FilledButton.icon(
            key: const ValueKey('lead-win'),
            onPressed: () => unawaited(_transition((x) => env.api.win(x.id))),
            icon: const Icon(Icons.emoji_events_outlined),
            label: Text(l.salesWin),
          ),
          OutlinedButton.icon(
            key: const ValueKey('lead-lose'),
            onPressed: () => unawaited(_lose()),
            icon: const Icon(Icons.thumb_down_outlined),
            label: Text(l.salesLose),
          ),
        ] else
          OutlinedButton.icon(
            key: const ValueKey('lead-reopen'),
            onPressed: () =>
                unawaited(_transition((x) => env.api.reopen(x.id))),
            icon: const Icon(Icons.replay),
            label: Text(l.salesReopen),
          ),
      ],
    );
  }

  Widget _owner(AppLocalizations l) {
    final ids = {for (final p in _people) p.id};
    final current = _lead?.owner;
    final people = [
      ..._people,
      if (current != null && !ids.contains(current.id)) current,
    ];
    if (people.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<int>(
      key: const ValueKey('lead-owner'),
      initialValue: people.any((p) => p.id == _ownerId) ? _ownerId : null,
      decoration: InputDecoration(labelText: l.salesOwner),
      items: [
        for (final p in people)
          DropdownMenuItem(value: p.id, child: Text(p.displayName)),
      ],
      onChanged: _readOnly ? null : (v) => setState(() => _ownerId = v),
    );
  }

  List<Widget> _fields(AppLocalizations l) {
    final lead = _lead;
    final value = _valueNumber;
    return [
      if (lead != null) _actions(l, lead),
      if (lead != null && lead.status == LeadStatus.lost)
        Container(
          key: const ValueKey('lost-banner'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(l.salesLostBanner(lead.lostReason)),
        ),
      if (lead?.customerName != null)
        Text(l.financeCustomer(lead!.customerName!)),
      TextField(
        key: const ValueKey('lead-title'),
        controller: _title,
        enabled: !_readOnly,
        maxLength: 200,
        decoration: InputDecoration(
          labelText: l.salesTitle,
          errorText: _submitted && _title.text.trim().isEmpty
              ? l.salesTitleRequired
              : null,
        ),
      ),
      TextField(
        key: const ValueKey('lead-value'),
        controller: _value,
        enabled: !_readOnly,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: l.salesValue,
          errorText: _submitted && value == null
              ? l.financeAmountInvalid
              : null,
          helperText: value == null || value == 0 ? null : formatAmount(value),
        ),
        onChanged: (_) => setState(() {}),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.salesProbability(toPersianDigits(_probability.round())),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Slider(
            key: const ValueKey('lead-prob'),
            value: _probability,
            max: 100,
            divisions: 100,
            label: toPersianDigits(_probability.round()),
            onChanged: _readOnly
                ? null
                : (v) => setState(() => _probability = v),
          ),
          if (value != null)
            Text(
              l.salesWeighted(
                formatRial(l, (value * _probability.round()) ~/ 100),
              ),
            ),
        ],
      ),
      _owner(l),
      TextField(
        key: const ValueKey('lead-description'),
        controller: _description,
        enabled: !_readOnly,
        minLines: 2,
        maxLines: 6,
        decoration: InputDecoration(labelText: l.salesDescription),
      ),
      Text(l.moneyLabels, style: Theme.of(context).textTheme.labelLarge),
      LabelChips(
        labels: _labels,
        selected: _labelIds,
        onChanged: _readOnly ? null : (s) => setState(() => _labelIds = s),
        onCreate: _readOnly ? null : () => unawaited(_newLabel()),
      ),
      if (lead == null)
        Text(l.salesSaveFirstFiles)
      else
        SubjectFiles(
          api: env.api.workspace,
          live: env.live,
          subjectId: lead.subjectId,
          userId: env.userId,
          pickFile: env.pickFile,
          saveFile: env.saveFile,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_lead);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_saved ? l.salesEdit : l.salesNew),
          actions: [
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
