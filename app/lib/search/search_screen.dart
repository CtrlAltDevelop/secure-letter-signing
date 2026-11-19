import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/search/models.dart';
import 'package:letter_signing/search/search_api.dart';
import 'package:letter_signing/search/unified_search_controller.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/module_label.dart';
import 'package:letter_signing/workspace/open_target.dart';

/// Modules offered as filter chips (the server skips the ones switched off).
const searchModules = [
  'tasks',
  'projects',
  'letters',
  'meetings',
  'crm',
  'chat',
  'notes',
  'files',
];

/// Unified search over every module and file names (`GET /search`): results are grouped by
/// module; tap opens the object through [open].
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.api, required this.open});

  final SearchApi api;
  final OpenFn open;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final UnifiedSearchController _c = UnifiedSearchController(widget.api);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey('search-field'),
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l.searchHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          onChanged: _c.setQuery,
        ),
      ),
      body: PageBody(
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) => Column(
            children: [
              _chips(l),
              Expanded(child: _results(context, l)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chips(AppLocalizations l) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final m in searchModules)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilterChip(
              key: ValueKey('search-chip-$m'),
              label: Text(moduleLabel(l, m)),
              selected: _c.modules.contains(m),
              onSelected: (_) => _c.toggleModule(m),
            ),
          ),
      ],
    ),
  );

  Widget _results(BuildContext context, AppLocalizations l) {
    if (_c.tooShort) {
      return EmptyState(
        icon: Icons.search,
        title: l.searchPrompt,
        message: l.searchMinChars,
      );
    }
    if (_c.loading) return const Center(child: CircularProgressIndicator());
    final error = _c.error;
    if (error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: error is SearchRateLimited
            ? l.searchRateLimited
            : l.searchFailed,
      );
    }
    if (_c.groups.isEmpty) {
      return EmptyState(icon: Icons.search_off, title: l.searchNoResults);
    }
    return ListView(
      children: [
        for (final g in _c.groups) ...[
          SectionHeader(moduleLabel(l, g.module)),
          for (final h in g.hits) _tile(context, h, l),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, SearchHit h, AppLocalizations l) =>
      ListTile(
        key: ValueKey('hit-${h.module}-${h.kind}-${h.id}'),
        leading: Icon(h.isFile ? Icons.attach_file : Icons.article_outlined),
        title: Text(h.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: h.snippet.isEmpty
            ? null
            : Text(h.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => unawaited(
          h.isFile ? _fileInfo(context, h, l) : widget.open(context, h.target),
        ),
      );

  /// The hit names a file, not its owner's module, so there is no screen to open yet:
  /// show which object holds it.
  Future<void> _fileInfo(
    BuildContext context,
    SearchHit h,
    AppLocalizations l,
  ) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(h.title),
      content: Text(l.searchFileIn(h.snippet)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l.commonClose),
        ),
      ],
    ),
  );
}
