import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/create_letter_screen.dart';
import 'package:letter_signing/letters/letter_card.dart';
import 'package:letter_signing/letters/letter_detail_screen.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/letters_search_sheet.dart';
import 'package:letter_signing/letters/letters_v2_api.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/notifications_screen.dart';
import 'package:letter_signing/letters/secretariat_screen.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';

/// The boxes of the letters list, in tab order.
const letterBoxes = ['inbox', 'outbox', 'archive', 'all'];

/// Letters visible to this user, newest first, in four boxes (inbox, outbox, archive, all);
/// chained letters nest under their parent.
class LettersListScreen extends StatefulWidget {
  const LettersListScreen({
    super.key,
    required this.env,
    this.embedded = false,
  });
  final LettersEnv env;

  /// True when the app shell supplies the title and the notification bell.
  final bool embedded;

  @override
  State<LettersListScreen> createState() => _LettersListScreenState();
}

class _LettersListScreenState extends State<LettersListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: letterBoxes.length,
    vsync: this,
  )..addListener(_onTab);
  List<LetterBrief> _all = const [];
  List<LabelInfo> _labels = const [];
  Object? _error;
  bool _loading = true;
  LetterSearch _criteria = const LetterSearch(box: 'inbox');
  final _search = TextEditingController();
  final Set<String> _statuses = {};
  StreamSubscription<dynamic>? _sub;

  LettersEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    _sub = env.live.events.listen((e) {
      if (e.isLetter && mounted) unawaited(_load());
    });
    unawaited(_load());
    unawaited(_loadLabels());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _tabs
      ..removeListener(_onTab)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _onTab() {
    if (_tabs.indexIsChanging) return;
    final box = letterBoxes[_tabs.index];
    if (box == _criteria.box) return;
    setState(() {
      _criteria = _criteria.copyWith(box: box);
      _loading = true;
    });
    unawaited(_load());
  }

  Future<void> _loadLabels() async {
    final labels = await env.labels();
    if (mounted) setState(() => _labels = labels);
  }

  Future<List<LetterBrief>> _fetch() => _criteria.activeCount == 0
      ? env.api.list(box: _criteria.box)
      : env.v2.search(_criteria);

  Future<void> _load() async {
    try {
      final rows = await _fetch();
      if (!mounted) return;
      setState(() {
        _all = rows;
        _error = null;
        _loading = false;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  bool _matches(LetterBrief l) =>
      _statuses.isEmpty || _statuses.contains(l.status);

  /// Top-level letters plus their (filtered) thread children, as (letter, depth).
  List<(LetterBrief, int)> _rows() {
    final ids = {for (final l in _all) l.id};
    final kids = <String, List<LetterBrief>>{};
    for (final l in _all) {
      final parent = l.parentId;
      if (parent != null && ids.contains(parent)) {
        kids.putIfAbsent(parent, () => []).add(l);
      }
    }
    final out = <(LetterBrief, int)>[];
    void add(LetterBrief l, int depth) {
      final children = kids[l.id] ?? const [];
      if (_matches(l) || children.any(_matches)) out.add((l, depth));
      for (final c in children.reversed) {
        add(c, depth + 1);
      }
    }

    for (final l in _all) {
      if (l.parentId == null || !ids.contains(l.parentId)) add(l, 0);
    }
    return out;
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LetterDetailScreen(env: env, letterId: id),
      ),
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<LetterBrief>(
      MaterialPageRoute(builder: (_) => CreateLetterScreen(env: env)),
    );
    if (created != null && mounted) unawaited(_load());
  }

  Future<void> _openSecretariat() => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => SecretariatScreen(env: env)));

  Future<void> _advanced() async {
    final picked = await showLetterSearchSheet(
      context,
      criteria: _criteria,
      labels: _labels,
    );
    if (picked == null || !mounted) return;
    _search.text = picked.q;
    setState(() {
      _criteria = picked;
      _loading = true;
    });
    unawaited(_load());
  }

  void _submitQuery(String v) {
    setState(() {
      _criteria = _criteria.copyWith(q: v.trim());
      _loading = true;
    });
    unawaited(_load());
  }

  void _clearAll() {
    _search.clear();
    setState(() {
      _criteria = LetterSearch(box: _criteria.box);
      _statuses.clear();
      _loading = true;
    });
    unawaited(_load());
  }

  Future<void> _toggleArchive(LetterBrief l) async {
    try {
      await env.v2.archive(l.id, archived: !l.archived);
      await _load();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _editLabels(LetterBrief l) async {
    final subject = l.subjectId;
    if (subject == null) return;
    final picked = await showLetterLabelsSheet(
      context,
      env: env,
      subjectId: subject,
      selected: l.labelIds,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _all = [
        for (final x in _all)
          if (x.id == l.id) x.copyWith(labelIds: picked) else x,
      ];
    });
  }

  Widget _statusFilters(AppLocalizations l) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final s in LetterStatus.all)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilterChip(
              label: Text(letterStatusLabel(l, s)),
              selected: _statuses.contains(s),
              onSelected: (on) => setState(() {
                if (on) {
                  _statuses.add(s);
                } else {
                  _statuses.remove(s);
                }
              }),
            ),
          ),
      ],
    ),
  );

  Widget _searchRow(AppLocalizations l) {
    final count = _criteria.activeCount;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.lettersSearchHint,
              suffixIcon: count == 0
                  ? null
                  : IconButton(
                      tooltip: l.lettersSearchClear,
                      icon: const Icon(Icons.close),
                      onPressed: _clearAll,
                    ),
            ),
            onSubmitted: _submitQuery,
          ),
        ),
        IconButton(
          tooltip: l.lettersAdvancedSearch,
          onPressed: _advanced,
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: const Icon(Icons.tune),
          ),
        ),
        if (env.canSecretariat)
          IconButton(
            tooltip: l.lettersSecretariat,
            onPressed: _openSecretariat,
            icon: const Icon(Icons.how_to_vote_outlined),
          ),
      ],
    );
  }

  Widget _stateBody(List<(LetterBrief, int)> rows, AppLocalizations l) {
    if (_loading) return const SkeletonList();
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 48),
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l.lettersLoadFailed,
            message: '$_error',
            action: OutlinedButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                unawaited(_load());
              },
              icon: const Icon(Icons.refresh),
              label: Text(l.commonRetry),
            ),
          ),
        ],
      );
    }
    if (rows.isEmpty) return _empty(l);
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final (letter, depth) in rows)
          Padding(
            key: ValueKey(letter.id),
            padding: EdgeInsetsDirectional.only(
              start: 20.0 * depth,
              bottom: Tokens.gap * 0.75,
            ),
            child: LetterCard(
              letter: letter,
              depth: depth,
              mine: letter.creatorId == env.userId,
              labels: _labels,
              onTap: () => _open(letter.id),
              onToggleArchive: () => unawaited(_toggleArchive(letter)),
              onEditLabels: letter.subjectId == null
                  ? null
                  : () => unawaited(_editLabels(letter)),
            ),
          ),
      ],
    );
  }

  Widget _empty(AppLocalizations l) {
    final filtered = _criteria.activeCount > 0 || _statuses.isNotEmpty;
    return ListView(
      children: [
        const SizedBox(height: 48),
        EmptyState(
          icon: Icons.mail_outline,
          title: filtered ? l.lettersNoMatchTitle : l.lettersEmptyTitle,
          message: filtered ? l.lettersNoMatchMessage : l.lettersEmptyMessage,
          action: !filtered && env.canCreate
              ? FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l.lettersNew),
                )
              : null,
        ),
      ],
    );
  }

  Widget _tabBar(AppLocalizations l) => TabBar(
    controller: _tabs,
    tabs: [
      Tab(text: l.lettersBoxInbox),
      Tab(text: l.lettersBoxOutbox),
      Tab(text: l.lettersBoxArchive),
      Tab(text: l.lettersBoxAll),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = _rows();
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(l.moduleLetters),
              actions: [NotificationBell(env: env, onOpenLetter: _open)],
            ),
      floatingActionButton: env.canCreate && rows.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _create,
              tooltip: l.lettersNew,
              icon: const Icon(Icons.edit_outlined),
              label: Text(l.lettersNew),
            )
          : null,
      body: PageBody(
        child: Column(
          children: [
            _tabBar(l),
            const SizedBox(height: 8),
            _searchRow(l),
            const SizedBox(height: 8),
            _statusFilters(l),
            const SizedBox(height: 4),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _stateBody(rows, l),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
