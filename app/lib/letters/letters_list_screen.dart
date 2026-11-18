import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/create_letter_screen.dart';
import 'package:letter_signing/letters/letter_detail_screen.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/notifications_screen.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// History: everything visible to this user, newest first; chained letters nest under their parent.
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

class _LettersListScreenState extends State<LettersListScreen> {
  List<LetterBrief> _all = const [];
  Object? _error;
  bool _loading = true;
  String _query = '';
  final _search = TextEditingController();
  final Set<String> _statuses = {};
  StreamSubscription<dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.env.live.events.listen((e) {
      if (e.isLetter && mounted) unawaited(_load());
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.env.api.list(q: _query);
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
      if (l.parentId != null && ids.contains(l.parentId)) {
        kids.putIfAbsent(l.parentId!, () => []).add(l);
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
        builder: (_) => LetterDetailScreen(env: widget.env, letterId: id),
      ),
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<LetterBrief>(
      MaterialPageRoute(builder: (_) => CreateLetterScreen(env: widget.env)),
    );
    if (created != null && mounted) unawaited(_load());
  }

  Widget _filters() => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final s in LetterStatus.all)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(statusLabel(s)),
              selected: _statuses.contains(s),
              onSelected: (on) {
                setState(() {
                  if (on) {
                    _statuses.add(s);
                  } else {
                    _statuses.remove(s);
                  }
                });
              },
            ),
          ),
      ],
    ),
  );

  Widget _searchField() => TextField(
    controller: _search,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search),
      hintText: 'Search titles',
      suffixIcon: _query.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.close),
              onPressed: () {
                _search.clear();
                setState(() => _query = '');
                unawaited(_load());
              },
            ),
    ),
    onSubmitted: (v) {
      setState(() => _query = v.trim());
      unawaited(_load());
    },
  );

  Widget _stateBody(List<(LetterBrief, int)> rows) {
    if (_loading) return const SkeletonList();
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 48),
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load letters',
            message: '$_error',
            action: OutlinedButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                unawaited(_load());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }
    if (rows.isEmpty) {
      final filtered = _query.isNotEmpty || _statuses.isNotEmpty;
      return ListView(
        children: [
          const SizedBox(height: 48),
          EmptyState(
            icon: Icons.mail_outline,
            title: filtered ? 'No matching letters' : 'No letters yet',
            message: filtered
                ? 'Try a different search or clear the filters.'
                : 'Letters you write or that are shared with you appear here.',
            action: !filtered && widget.env.canCreate
                ? FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('New letter'),
                  )
                : null,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final (l, depth) in rows)
          Padding(
            key: ValueKey(l.id),
            padding: EdgeInsets.only(
              left: 20.0 * depth,
              bottom: Tokens.gap * 0.75,
            ),
            child: _LetterCard(
              letter: l,
              depth: depth,
              mine: l.creatorId == widget.env.userId,
              onTap: () => _open(l.id),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Letters'),
              actions: [NotificationBell(env: widget.env, onOpenLetter: _open)],
            ),
      floatingActionButton: widget.env.canCreate && rows.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _create,
              tooltip: 'New letter',
              icon: const Icon(Icons.edit_outlined),
              label: const Text('New letter'),
            )
          : null,
      body: PageBody(
        child: Column(
          children: [
            _searchField(),
            const SizedBox(height: 8),
            _filters(),
            const SizedBox(height: 4),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _stateBody(rows),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({
    required this.letter,
    required this.depth,
    required this.mine,
    required this.onTap,
  });
  final LetterBrief letter;
  final int depth;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final date = fmtDate(letter.sentAt ?? letter.createdAt);
    final public = letter.visibility == 'public';
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (depth > 0) ...[
            Icon(
              Icons.subdirectory_arrow_right,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('#${letter.no}', style: muted),
                    const SizedBox(width: 8),
                    StatusChip(letter.status),
                    const Spacer(),
                    if (mine)
                      Icon(Icons.edit_note, size: 18, color: scheme.secondary),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  letter.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    Text(
                      mine ? 'Created by you' : 'Shared with you',
                      style: muted,
                    ),
                    Text(date, style: muted),
                    Text(public ? 'Public' : 'Private', style: muted),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
