import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/crm/crm_env.dart';
import 'package:letter_signing/crm/crm_ui.dart';
import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';
import 'package:letter_signing/workspace/widgets/label_create_sheet.dart';

/// Contact details, notes and labels of a customer file; managers and members edit labels.
class CustomerOverviewTab extends StatefulWidget {
  const CustomerOverviewTab({
    super.key,
    required this.env,
    required this.customer,
  });
  final CrmEnv env;
  final Customer customer;

  @override
  State<CustomerOverviewTab> createState() => _CustomerOverviewTabState();
}

class _CustomerOverviewTabState extends State<CustomerOverviewTab> {
  List<LabelInfo> _labels = const [];
  late Set<int> _selected = {...widget.customer.labelIds};

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.env.labels().then((v) {
        if (mounted) setState(() => _labels = v);
      }),
    );
  }

  Future<void> _setLabels(Set<int> next) async {
    final failed = AppLocalizations.of(context).crmSaveFailed;
    final messenger = ScaffoldMessenger.of(context);
    final before = _selected;
    setState(() => _selected = next);
    try {
      await widget.env.api.workspace.setLabels(
        widget.customer.subjectId,
        next.toList(),
      );
    } on Object {
      if (mounted) setState(() => _selected = before);
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Future<void> _newLabel() async {
    final label = await showLabelCreateSheet(context, widget.env.api.workspace);
    if (label == null || !mounted) return;
    widget.env.invalidateLabels();
    final labels = await widget.env.labels();
    if (!mounted) return;
    setState(() => _labels = labels);
    await _setLabels({..._selected, label.id});
  }

  Widget _row(String label, String value, {bool ltr = false}) => value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textDirection: ltr ? TextDirection.ltr : null,
                  textAlign: ltr ? TextAlign.end : null,
                ),
              ),
            ],
          ),
        );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.customer;
    final canLabel = c.can.label;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  children: [
                    _row(l.crmFieldKind, customerKindLabel(l, c.kind)),
                    _row(l.crmFieldStatus, customerStatusLabel(l, c.status)),
                    _row(l.crmFieldLegalName, c.legalName),
                    _row(l.crmFieldRegistrationNo, c.registrationNo, ltr: true),
                    _row(l.crmFieldNationalId, c.nationalId, ltr: true),
                    _row(l.crmFieldPhone, c.phone, ltr: true),
                    _row(l.crmFieldMobile, c.mobile, ltr: true),
                    _row(l.crmFieldEmail, c.email, ltr: true),
                    _row(l.crmFieldAddress, c.address),
                    _row(l.crmFieldNotes, c.notes),
                    _row(l.crmFieldOwner, c.owner?.displayName ?? ''),
                  ],
                ),
              ),
              SectionHeader(l.labelsTitle),
              LabelChips(
                labels: _labels,
                selected: _selected,
                onChanged: canLabel ? (s) => unawaited(_setLabels(s)) : null,
                onCreate: canLabel ? () => unawaited(_newLabel()) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
