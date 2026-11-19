import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/crm/crm_env.dart';
import 'package:letter_signing/crm/crm_controller.dart';
import 'package:letter_signing/crm/crm_ui.dart';
import 'package:letter_signing/crm/customer_detail_screen.dart';
import 'package:letter_signing/crm/customer_form_screen.dart';
import 'package:letter_signing/crm/customer_import_screen.dart';
import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show SkeletonList;
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/choice_row.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';

/// The CRM module: the customer files I am a member of, with search, status and label
/// filters; import (permission `customer.import`) lives in the toolbar.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.env});
  final CrmEnv env;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final CustomersController _c = CustomersController(
    api: widget.env.api,
    live: widget.env.live,
  )..addListener(_rebuild);
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

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context)
        .push<Object>(MaterialPageRoute(builder: (_) => page));
    if (mounted) unawaited(_c.load());
  }

  void _set(CustomerFilter f) => unawaited(_c.setFilter(f));

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
            hintText: l.crmSearchHint,
          ),
          onSubmitted: (v) => _set(f.copyWith(q: v.trim())),
        ),
        const SizedBox(height: 8),
        ChoiceRow(
          options: {
            '': l.crmFilterAll,
            for (final s in CustomerStatus.all) s: customerStatusLabel(l, s),
          },
          value: f.statuses.isEmpty ? '' : f.statuses.first,
          onChanged: (v) =>
              _set(f.copyWith(statuses: v.isEmpty ? <String>{} : {v})),
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
        title: l.crmLoadFailed,
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
        icon: Icons.contacts_outlined,
        title: l.crmEmptyTitle,
        message: l.crmEmptyMessage,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in _c.items)
          CustomerTile(
            customer: c,
            labels: _labels,
            onTap: () => unawaited(
              _push(CustomerDetailScreen(env: widget.env, customerId: c.id)),
            ),
          ),
        if (_c.hasMore)
          TextButton(
            onPressed: () => unawaited(_c.loadMore()),
            child: Text(l.crmLoadMore),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: widget.env.canCreate
          ? FloatingActionButton.extended(
              onPressed: () =>
                  unawaited(_push(CustomerFormScreen(env: widget.env))),
              tooltip: l.crmNew,
              icon: const Icon(Icons.add),
              label: Text(l.crmNew),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _c.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.env.canImport)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        key: const ValueKey('crm-import'),
                        onPressed: () => unawaited(
                          _push(CustomerImportScreen(env: widget.env)),
                        ),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(l.crmImport),
                      ),
                    ),
                  _filters(l),
                  const SizedBox(height: 8),
                  _body(l),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One customer in the list.
class CustomerTile extends StatelessWidget {
  const CustomerTile({
    super.key,
    required this.customer,
    required this.onTap,
    this.labels = const [],
  });
  final Customer customer;
  final VoidCallback onTap;
  final List<LabelInfo> labels;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final contact = [
      customer.mobile,
      customer.phone,
      customer.email,
    ].where((e) => e.isNotEmpty).join(' · ');
    final mine = labels.where((x) => customer.labelIds.contains(x.id)).toList();
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                customer.isCompany ? Icons.business : Icons.person_outline,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customer.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusPill(
                customerStatusLabel(l, customer.status),
                tone: customerStatusTone(customer.status),
              ),
            ],
          ),
          if (contact.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(contact, style: muted, textDirection: TextDirection.ltr),
          ],
          if (mine.isNotEmpty) ...[
            const SizedBox(height: 4),
            LabelChips(labels: mine, selected: {for (final x in mine) x.id}),
          ],
        ],
      ),
    );
  }
}
