import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show SkeletonList;
import 'package:letter_signing/meetings/meeting_detail_screen.dart';
import 'package:letter_signing/meetings/meeting_form_screen.dart';
import 'package:letter_signing/meetings/meeting_templates_screen.dart';
import 'package:letter_signing/meetings/meeting_ui.dart';
import 'package:letter_signing/meetings/meetings_api.dart';
import 'package:letter_signing/meetings/meetings_controller.dart';
import 'package:letter_signing/meetings/meetings_env.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/widgets/jalali_date_field.dart';

/// The Meetings module: upcoming first, filtered by status, kind, "mine", text and a Jalali
/// date range.
class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key, required this.env});
  final MeetingsEnv env;

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  late final MeetingsController _c = MeetingsController(
    api: widget.env.api,
    live: widget.env.live,
  );
  final _search = TextEditingController();

  MeetingsEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    unawaited(_c.load());
  }

  @override
  void dispose() {
    _c.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final saved = await Navigator.of(context).push<MeetingOut>(
      MaterialPageRoute(builder: (_) => MeetingFormScreen(env: env)),
    );
    if (saved != null && mounted) unawaited(_c.load());
  }

  Future<void> _open(MeetingBrief m) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MeetingDetailScreen(env: env, meetingId: m.id),
      ),
    );
    if (mounted) unawaited(_c.load());
  }

  Future<void> _templates() => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => MeetingTemplatesScreen(env: env)),
  );

  Future<void> _filters() async {
    final picked = await showModalBottomSheet<MeetingFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(filter: _c.filter),
    );
    if (picked != null) {
      _search.text = picked.q;
      await _c.setFilter(picked);
    }
  }

  Widget _searchRow(AppLocalizations l) {
    final count = _c.filter.activeCount;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.meetingsSearchHint,
            ),
            onSubmitted: (v) =>
                unawaited(_c.setFilter(_c.filter.copyWith(q: v.trim()))),
          ),
        ),
        IconButton(
          tooltip: l.meetingsFilters,
          onPressed: _filters,
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: const Icon(Icons.tune),
          ),
        ),
        IconButton(
          tooltip: l.meetingTemplatesTitle,
          onPressed: _templates,
          icon: const Icon(Icons.copy_all_outlined),
        ),
      ],
    );
  }

  Widget _body(AppLocalizations l) {
    if (_c.loading) return const SkeletonList();
    if (_c.error != null && _c.items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 48),
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l.meetingsLoadFailed,
            message: '${_c.error}',
            action: OutlinedButton.icon(
              onPressed: () => unawaited(_c.load()),
              icon: const Icon(Icons.refresh),
              label: Text(l.commonRetry),
            ),
          ),
        ],
      );
    }
    if (_c.items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 48),
          EmptyState(
            icon: Icons.groups_outlined,
            title: l.meetingsEmptyTitle,
            message: l.meetingsEmptyMessage,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final m in _c.items)
          Padding(
            key: ValueKey(m.id),
            padding: const EdgeInsets.only(bottom: 12),
            child: _MeetingCard(meeting: m, onTap: () => unawaited(_open(m))),
          ),
        if (_c.hasMore)
          TextButton(
            onPressed: () => unawaited(_c.loadMore()),
            child: Text(l.tasksLoadMore),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          tooltip: l.meetingNew,
          icon: const Icon(Icons.add),
          label: Text(l.meetingNew),
        ),
        body: PageBody(
          child: Column(
            children: [
              _searchRow(l),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(onRefresh: _c.load, child: _body(l)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting, required this.onTap});
  final MeetingBrief meeting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final m = meeting;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MeetingStatusPill(m.status),
              if (m.isOrganizational)
                StatusPill(l.meetingKindOrganizational, tone: Tone.info),
              if (m.unseen) const Icon(Icons.fiber_manual_record, size: 10),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            m.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(meetingWhen(m.startsAt, l.meetingNoDate), style: muted),
          Wrap(
            spacing: 12,
            children: [
              if (m.location.isNotEmpty) Text(m.location, style: muted),
              Text(
                l.meetingAttendeeCount(toPersianDigits(m.attendeeCount)),
                style: muted,
              ),
              if (m.resolutionsTotal > 0)
                Text(
                  l.meetingResolutionCount(
                    toPersianDigits(m.resolutionsDone),
                    toPersianDigits(m.resolutionsTotal),
                  ),
                  style: muted,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filter});
  final MeetingFilter filter;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late MeetingFilter _f = widget.filter;

  Widget _dropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: (v) => onChanged(v ?? ''),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            l.meetingsFilters,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: l.meetingFieldStatus,
            value: _f.status,
            items: [
              DropdownMenuItem(value: '', child: Text(l.tasksFilterAll)),
              for (final s in MeetingStatus.all)
                DropdownMenuItem(
                  value: s,
                  child: Text(meetingStatusLabel(l, s)),
                ),
            ],
            onChanged: (v) => setState(() => _f = _f.copyWith(status: v)),
          ),
          _dropdown(
            label: l.meetingFieldKind,
            value: _f.kind,
            items: [
              DropdownMenuItem(value: '', child: Text(l.meetingKindAny)),
              for (final k in MeetingKind.all)
                DropdownMenuItem(value: k, child: Text(meetingKindLabel(l, k))),
            ],
            onChanged: (v) => setState(() => _f = _f.copyWith(kind: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.meetingsMineOnly),
            value: _f.mine,
            onChanged: (v) => setState(() => _f = _f.copyWith(mine: v)),
          ),
          JalaliDateField(
            label: l.meetingsFrom,
            value: _f.from,
            onChanged: (d) => setState(
              () => _f = d == null
                  ? _f.copyWith(clearFrom: true)
                  : _f.copyWith(from: d),
            ),
          ),
          const SizedBox(height: 12),
          JalaliDateField(
            label: l.meetingsTo,
            value: _f.to,
            onChanged: (d) => setState(
              () => _f = d == null
                  ? _f.copyWith(clearTo: true)
                  : _f.copyWith(to: d),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const MeetingFilter()),
                child: Text(l.lettersSearchReset),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_f),
                child: Text(l.lettersSearchApply),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
