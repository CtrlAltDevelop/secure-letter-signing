import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show SkeletonList;
import 'package:letter_signing/notes/models.dart';
import 'package:letter_signing/notes/note_card.dart';
import 'package:letter_signing/notes/note_editor_screen.dart';
import 'package:letter_signing/notes/notes_controller.dart';
import 'package:letter_signing/notes/notes_env.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';

const _wideBreakpoint = 600.0;
const _gap = 8.0;

/// The Notes module: my personal notes as coloured cards (pinned first), with search, a label
/// filter, an archive toggle and a grid/list switch.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.env});
  final NotesEnv env;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final NotesController _c = NotesController(
    api: widget.env.api,
    live: widget.env.live,
  );
  final _search = TextEditingController();
  List<LabelInfo> _labels = const [];
  bool _grid = true;

  NotesEnv get env => widget.env;

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
    final labels = await env.labels();
    if (mounted) setState(() => _labels = labels);
  }

  Future<void> _open([NoteOut? note]) async {
    await Navigator.of(context).push<NoteOut>(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(env: env, note: note),
      ),
    );
    if (mounted) unawaited(_c.load());
  }

  Widget _toolbar(AppLocalizations l) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l.notesSearchHint,
          ),
          onSubmitted: (v) =>
              unawaited(_c.setFilter(_c.filter.copyWith(q: v.trim()))),
        ),
      ),
      IconButton(
        tooltip: _grid ? l.notesViewList : l.notesViewGrid,
        icon: Icon(_grid ? Icons.view_agenda_outlined : Icons.grid_view),
        onPressed: () => setState(() => _grid = !_grid),
      ),
      IconButton(
        tooltip: l.notesArchiveToggle,
        isSelected: _c.filter.archived,
        icon: const Icon(Icons.archive_outlined),
        selectedIcon: const Icon(Icons.archive),
        onPressed: () => unawaited(
          _c.setFilter(_c.filter.copyWith(archived: !_c.filter.archived)),
        ),
      ),
    ],
  );

  Widget _cards(List<NoteOut> rows, double width) {
    final cols = !_grid ? 1 : (width >= _wideBreakpoint ? 3 : 2);
    final cardWidth = (width - _gap * (cols - 1)) / cols;
    return Wrap(
      spacing: _gap,
      runSpacing: _gap,
      children: [
        for (final n in rows)
          SizedBox(
            key: ValueKey(n.id),
            width: cardWidth,
            child: NoteCard(
              note: n,
              labels: _labels,
              onTap: () => unawaited(_open(n)),
            ),
          ),
      ],
    );
  }

  Widget _section(String title, List<NoteOut> rows, double width) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 8, bottom: 6),
            child: Text(title, style: Theme.of(context).textTheme.labelLarge),
          ),
        _cards(rows, width),
      ],
    );
  }

  Widget _body(AppLocalizations l, double width) {
    if (_c.loading) {
      return const SizedBox(height: 360, child: SkeletonList(count: 3));
    }
    if (_c.error != null && _c.items.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.notesLoadFailed,
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
        icon: Icons.sticky_note_2_outlined,
        title: _c.filter.archived ? l.notesEmptyArchived : l.notesEmptyTitle,
        message: _c.filter.archived ? null : l.notesEmptyMessage,
      );
    }
    final pinned = _c.pinned;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(pinned.isEmpty ? '' : l.notesPinned, pinned, width),
        _section(pinned.isEmpty ? '' : l.notesOthers, _c.others, width),
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
          onPressed: _open,
          tooltip: l.notesNew,
          icon: const Icon(Icons.add),
          label: Text(l.notesNew),
        ),
        body: PageBody(
          child: RefreshIndicator(
            onRefresh: _c.load,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                _toolbar(l),
                if (_labels.isNotEmpty)
                  LabelChips(
                    labels: _labels,
                    selected: {?_c.filter.labelId},
                    single: true,
                    onChanged: (s) => unawaited(
                      _c.setFilter(
                        s.isEmpty
                            ? _c.filter.copyWith(clearLabel: true)
                            : _c.filter.copyWith(labelId: s.first),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, box) => _body(l, box.maxWidth),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
