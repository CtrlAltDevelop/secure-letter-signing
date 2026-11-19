import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show SkeletonList;
import 'package:letter_signing/sales/lead_form_screen.dart';
import 'package:letter_signing/sales/models.dart';
import 'package:letter_signing/sales/sales_controller.dart';
import 'package:letter_signing/sales/sales_env.dart';
import 'package:letter_signing/sales/sales_ui.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/choice_row.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';

/// A scrolling list of leads for [initialFilter]; with [showFilters] it has search, a status
/// choice and a label filter. Tapping a lead opens the editor and reloads afterwards.
class LeadsView extends StatefulWidget {
  const LeadsView({
    super.key,
    required this.env,
    this.initialFilter = const LeadFilter(),
    this.showFilters = false,
  });
  final SalesEnv env;
  final LeadFilter initialFilter;
  final bool showFilters;

  @override
  State<LeadsView> createState() => _LeadsViewState();
}

class _LeadsViewState extends State<LeadsView> {
  late final SalesController _c = SalesController(
    api: widget.env.api,
    live: widget.env.live,
    filter: widget.initialFilter,
  );
  final _search = TextEditingController();
  List<LabelInfo> _labels = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_c.load());
    unawaited(
      widget.env.labels().then((v) {
        if (mounted) setState(() => _labels = v);
      }),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Lead lead) async {
    await Navigator.of(context).push<Lead>(
      MaterialPageRoute(
        builder: (_) => LeadFormScreen(env: widget.env, lead: lead),
      ),
    );
    if (mounted) unawaited(_c.load());
  }

  void _set(LeadFilter f) => unawaited(_c.setFilter(f));

  Widget _filters(AppLocalizations l) {
    final f = _c.filter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l.salesSearchHint,
          ),
          onSubmitted: (v) => _set(f.copyWith(q: v.trim())),
        ),
        const SizedBox(height: 8),
        ChoiceRow(
          options: {
            '': l.financeFilterAll,
            for (final s in LeadStatus.all) s: leadStatusLabel(l, s),
          },
          value: f.statuses.isEmpty ? '' : f.statuses.first,
          onChanged: (v) => _set(f.copyWith(statuses: v.isEmpty ? [] : [v])),
        ),
        if (_labels.isNotEmpty)
          LabelChips(
            labels: _labels,
            selected: {?f.labelId},
            single: true,
            onChanged: (s) => _set(
              s.isEmpty
                  ? f.copyWith(clearLabel: true)
                  : f.copyWith(labelId: s.first),
            ),
          ),
      ],
    );
  }

  Widget _body(AppLocalizations l) {
    if (_c.loading) {
      return const SizedBox(height: 360, child: SkeletonList(count: 3));
    }
    if (_c.error != null && _c.items.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.salesLoadFailed,
        message: '${_c.error}',
        action: OutlinedButton.icon(
          onPressed: () => unawaited(_c.load()),
          icon: const Icon(Icons.refresh),
          label: Text(l.commonRetry),
        ),
      );
    }
    if (_c.items.isEmpty) {
      return EmptyState(
        icon: Icons.trending_up,
        title: l.salesEmptyTitle,
        message: l.salesEmptyMessage,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final lead in _c.items)
          LeadTile(lead: lead, onTap: () => unawaited(_open(lead))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _c.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (widget.showFilters) _filters(l),
            const SizedBox(height: 8),
            _body(l),
          ],
        ),
      ),
    );
  }
}

/// All open leads of one probability bucket, opened from the monitoring tab.
class LeadsBucketScreen extends StatelessWidget {
  const LeadsBucketScreen({super.key, required this.env, required this.bucket});
  final SalesEnv env;
  final String bucket;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        AppLocalizations.of(context).salesBucketLeads(bucketLabel(bucket)),
      ),
    ),
    body: PageBody(
      child: LeadsView(
        env: env,
        initialFilter: LeadFilter(bucket: bucket),
      ),
    ),
  );
}
