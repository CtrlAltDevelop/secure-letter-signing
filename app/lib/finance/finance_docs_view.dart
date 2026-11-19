import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/finance/finance_controller.dart';
import 'package:letter_signing/finance/finance_env.dart';
import 'package:letter_signing/finance/finance_form_screen.dart';
import 'package:letter_signing/finance/finance_ui.dart';
import 'package:letter_signing/finance/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show SkeletonList;
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/choice_row.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';

/// A scrolling list of finance documents for [initialFilter]. With [showFilters] it also has
/// search, direction/kind/status choices and a label filter; [sort] reorders the rows
/// (e.g. oldest due date first). Tapping a row opens the editor and reloads afterwards.
class FinanceDocsView extends StatefulWidget {
  const FinanceDocsView({
    super.key,
    required this.env,
    this.initialFilter = const FinanceFilter(),
    this.showFilters = false,
    this.sort,
    this.header,
    this.emptyTitle,
    this.emptyMessage,
  });

  final FinanceEnv env;
  final FinanceFilter initialFilter;
  final bool showFilters;
  final int Function(FinanceDoc a, FinanceDoc b)? sort;
  final Widget? header;
  final String? emptyTitle;
  final String? emptyMessage;

  @override
  State<FinanceDocsView> createState() => _FinanceDocsViewState();
}

class _FinanceDocsViewState extends State<FinanceDocsView> {
  late final FinanceController _c = FinanceController(
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
    unawaited(_loadLabels());
  }

  @override
  void dispose() {
    _c.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadLabels() async {
    final labels = await widget.env.labels();
    if (mounted) setState(() => _labels = labels);
  }

  Future<void> _open(FinanceDoc d) async {
    await Navigator.of(context).push<FinanceDoc>(
      MaterialPageRoute(
        builder: (_) => FinanceFormScreen(env: widget.env, doc: d),
      ),
    );
    if (mounted) unawaited(_c.load());
  }

  void _set(FinanceFilter f) => unawaited(_c.setFilter(f));

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
            hintText: l.financeSearchHint,
          ),
          onSubmitted: (v) => _set(f.copyWith(q: v.trim())),
        ),
        const SizedBox(height: 8),
        ChoiceRow(
          options: {
            '': l.financeFilterAll,
            for (final d in FinanceDirection.all) d: directionLabel(l, d),
          },
          value: f.direction,
          onChanged: (v) => _set(f.copyWith(direction: v)),
        ),
        ChoiceRow(
          options: {
            '': l.financeFilterAll,
            for (final k in FinanceKind.creatable) k: kindLabel(l, k),
          },
          value: f.kinds.isEmpty ? '' : f.kinds.first,
          onChanged: (v) => _set(f.copyWith(kinds: v.isEmpty ? [] : [v])),
        ),
        ChoiceRow(
          options: {
            '': l.financeFilterAll,
            for (final s in FinanceStatus.all) s: statusLabel(l, s),
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
        title: l.financeLoadFailed,
        message: '${_c.error}',
        action: OutlinedButton.icon(
          onPressed: () => unawaited(_c.load()),
          icon: const Icon(Icons.refresh),
          label: Text(l.commonRetry),
        ),
      );
    }
    final rows = [..._c.items];
    final sort = widget.sort;
    if (sort != null) rows.sort(sort);
    if (rows.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: widget.emptyTitle ?? l.financeEmptyTitle,
        message: widget.emptyMessage ?? l.financeEmptyMessage,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in rows)
          FinanceDocTile(doc: d, onTap: () => unawaited(_open(d))),
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
            ?widget.header,
            if (widget.showFilters) _filters(l),
            const SizedBox(height: 8),
            _body(l),
          ],
        ),
      ),
    );
  }
}

/// All documents of one report bucket (a month or a year), opened from the report table.
class FinanceDrillScreen extends StatelessWidget {
  const FinanceDrillScreen({
    super.key,
    required this.env,
    required this.title,
    required this.filter,
  });
  final FinanceEnv env;
  final String title;
  final FinanceFilter filter;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: PageBody(
      child: FinanceDocsView(env: env, initialFilter: filter),
    ),
  );
}
