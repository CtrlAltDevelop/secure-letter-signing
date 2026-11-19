import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/crm/crm_api.dart';
import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show fmtDateTime;
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/widgets/choice_row.dart';

/// Phone call reports of a customer file; a report can be turned into a follow-up task
/// (needs `task.create`).
class CustomerCallsTab extends StatefulWidget {
  const CustomerCallsTab({
    super.key,
    required this.api,
    required this.customerId,
    required this.userId,
    required this.canAdd,
    required this.canTask,
  });
  final CrmApi api;
  final String customerId;
  final int userId;
  final bool canAdd;
  final bool canTask;

  @override
  State<CustomerCallsTab> createState() => _CustomerCallsTabState();
}

class _CustomerCallsTabState extends State<CustomerCallsTab> {
  List<CallReport>? _calls;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final v = await widget.api.calls(widget.customerId);
      if (mounted) setState(() => _calls = v);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _add() async {
    final draft = await showDialog<_CallDraft>(
      context: context,
      builder: (_) => const _CallDialog(),
    );
    if (draft == null || !mounted) return;
    final failed = AppLocalizations.of(context).crmSaveFailed;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.addCall(
        widget.customerId,
        direction: draft.direction,
        contactName: draft.contact,
        summary: draft.summary,
        durationSeconds: draft.minutes * 60,
      );
      await _load();
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Future<void> _toTask(CallReport c) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.callToTask(
        widget.customerId,
        c.id,
        ownerIds: [widget.userId],
      );
      messenger.showSnackBar(SnackBar(content: Text(l.crmCallTaskCreated)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l.crmSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final calls = _calls;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              if (widget.canAdd)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    key: const ValueKey('crm-call-add'),
                    onPressed: () => unawaited(_add()),
                    icon: const Icon(Icons.add_call),
                    label: Text(l.crmCallNew),
                  ),
                ),
              if (_error != null && calls == null)
                Text('$_error')
              else if (calls == null)
                const Center(child: CircularProgressIndicator())
              else if (calls.isEmpty)
                EmptyState(icon: Icons.call_outlined, title: l.crmCallsEmpty)
              else
                for (final c in calls) _tile(l, c),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(AppLocalizations l, CallReport c) {
    final minutes = (c.durationSeconds / 60).round();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                c.direction == CallReport.incoming
                    ? Icons.call_received
                    : Icons.call_made,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.contactName.isEmpty ? l.crmCallNoContact : c.contactName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (widget.canTask)
                TextButton(
                  key: ValueKey('crm-call-task-${c.id}'),
                  onPressed: () => unawaited(_toTask(c)),
                  child: Text(l.crmCallToTask),
                ),
            ],
          ),
          if (c.summary.isNotEmpty) Text(c.summary),
          Text(
            [
              c.direction == CallReport.incoming ? l.crmCallIn : l.crmCallOut,
              if (minutes > 0) l.crmCallMinutes(toPersianDigits(minutes)),
              ?c.by?.displayName,
              if (c.at != null) fmtDateTime(c.at!.toLocal()),
            ].join(' · '),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CallDraft {
  const _CallDraft(this.direction, this.contact, this.summary, this.minutes);
  final String direction;
  final String contact;
  final String summary;
  final int minutes;
}

class _CallDialog extends StatefulWidget {
  const _CallDialog();

  @override
  State<_CallDialog> createState() => _CallDialogState();
}

class _CallDialogState extends State<_CallDialog> {
  final _contact = TextEditingController();
  final _summary = TextEditingController();
  final _minutes = TextEditingController();
  String _direction = CallReport.incoming;

  @override
  void dispose() {
    _contact.dispose();
    _summary.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.crmCallNew),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            ChoiceRow(
              options: {
                CallReport.incoming: l.crmCallIn,
                CallReport.outgoing: l.crmCallOut,
              },
              value: _direction,
              onChanged: (v) => setState(() => _direction = v),
            ),
            TextField(
              key: const ValueKey('crm-call-contact'),
              controller: _contact,
              decoration: InputDecoration(labelText: l.crmCallContact),
            ),
            TextField(
              key: const ValueKey('crm-call-summary'),
              controller: _summary,
              maxLines: 3,
              decoration: InputDecoration(labelText: l.crmCallSummary),
            ),
            TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.crmCallDuration),
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
          key: const ValueKey('crm-call-save'),
          onPressed: () => Navigator.pop(
            context,
            _CallDraft(
              _direction,
              _contact.text.trim(),
              _summary.text.trim(),
              int.tryParse(_minutes.text.trim()) ?? 0,
            ),
          ),
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
