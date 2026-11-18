import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/create_letter_screen.dart';
import 'package:letter_signing/letters/letter_detail_screen.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/notifications_screen.dart';

/// History: everything visible to this user, newest first; chained letters nest under their parent.
class LettersListScreen extends StatefulWidget {
  const LettersListScreen({super.key, required this.env});
  final LettersEnv env;

  @override
  State<LettersListScreen> createState() => _LettersListScreenState();
}

class _LettersListScreenState extends State<LettersListScreen> {
  List<LetterBrief> _all = const [];
  Object? _error;
  bool _loading = true;
  String _query = '';
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

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Letters'),
        actions: [NotificationBell(env: widget.env, onOpenLetter: _open)],
      ),
      floatingActionButton: widget.env.canCreate
          ? FloatingActionButton(
              onPressed: _create,
              tooltip: 'New letter',
              child: const Icon(Icons.edit),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search titles',
              ),
              onSubmitted: (v) {
                _query = v.trim();
                unawaited(_load());
              },
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final s in LetterStatus.all)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: FilterChip(
                      label: Text(statusLabel(s)),
                      selected: _statuses.contains(s),
                      onSelected: (on) => setState(
                        () => on ? _statuses.add(s) : _statuses.remove(s),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('$_error'),
                        ),
                      ],
                    )
                  : rows.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No letters')),
                      ],
                    )
                  : ListView(
                      children: [
                        for (final (l, depth) in rows)
                          Padding(
                            padding: EdgeInsets.only(left: 24.0 * depth),
                            child: ListTile(
                              key: ValueKey(l.id),
                              leading: depth > 0
                                  ? const Icon(Icons.subdirectory_arrow_right)
                                  : null,
                              title: Text('#${l.no}  ${l.title}'),
                              subtitle: Text(
                                l.visibility == 'public' ? 'Public' : 'Private',
                              ),
                              trailing: StatusChip(l.status),
                              onTap: () => _open(l.id),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
