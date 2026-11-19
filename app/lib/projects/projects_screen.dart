import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show SkeletonList;
import 'package:letter_signing/projects/groups_sheet.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/project_card.dart';
import 'package:letter_signing/projects/project_detail_screen.dart';
import 'package:letter_signing/projects/project_form_screen.dart';
import 'package:letter_signing/projects/project_ui.dart';
import 'package:letter_signing/projects/projects_controller.dart';
import 'package:letter_signing/projects/projects_env.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// The Projects module root: projects grouped by project group (collapsible), a status filter,
/// search, and for users with `project.create` a create button.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, required this.env});

  final ProjectsEnv env;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late final ProjectsController _c = ProjectsController(env: widget.env);
  final _search = TextEditingController();

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
    final created = await Navigator.of(context).push<ProjectOut>(
      MaterialPageRoute(builder: (_) => ProjectFormScreen(env: widget.env)),
    );
    if (created == null || !mounted) return;
    unawaited(_c.refresh());
    await _open(created.id);
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(env: widget.env, projectId: id),
      ),
    );
    if (mounted) unawaited(_c.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: widget.env.canCreate
          ? FloatingActionButton.extended(
              key: const ValueKey('project-create'),
              onPressed: () => unawaited(_create()),
              tooltip: l.projectNew,
              icon: const Icon(Icons.add),
              label: Text(l.projectNew),
            )
          : null,
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) => RefreshIndicator(
          onRefresh: _c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.fromSTEB(
              Tokens.gap,
              8,
              Tokens.gap,
              96,
            ),
            children: [
              _searchRow(context),
              const SizedBox(height: 8),
              _statusChips(context),
              const SizedBox(height: 8),
              ..._body(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchRow(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('projects-search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.projectsSearchHint,
              suffixIcon: _c.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l.tasksSearchClear,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        unawaited(_c.setQuery(''));
                      },
                    ),
            ),
            onSubmitted: (v) => unawaited(_c.setQuery(v)),
          ),
        ),
        IconButton(
          key: const ValueKey('groups-manage'),
          tooltip: l.groupsTitle,
          icon: const Icon(Icons.folder_copy_outlined),
          onPressed: () => unawaited(
            showGroupsSheet(context, _c, isManager: widget.env.isManager),
          ),
        ),
      ],
    );
  }

  Widget _statusChips(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final s in ['', ...ProjectStatus.all])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                key: ValueKey('status-$s'),
                label: Text(
                  s.isEmpty ? l.tasksTabAll : projectStatusLabel(l, s),
                ),
                selected: _c.status == s,
                onSelected: (_) => unawaited(_c.setStatus(s)),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_c.loading && _c.projects.isEmpty) {
      return const [SizedBox(height: 360, child: SkeletonList(count: 3))];
    }
    if (_c.error != null && _c.projects.isEmpty) {
      return [
        EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l.projectsLoadFailed,
          message: '${_c.error}',
          action: OutlinedButton.icon(
            onPressed: () => unawaited(_c.load()),
            icon: const Icon(Icons.refresh),
            label: Text(l.commonRetry),
          ),
        ),
      ];
    }
    if (_c.projects.isEmpty) return [_empty(context)];
    return [for (final s in _c.sections) ..._section(context, s)];
  }

  Widget _empty(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_c.filtered) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: l.projectsEmptyFilteredTitle,
        message: l.tasksEmptyFilteredMessage,
      );
    }
    return EmptyState(
      icon: Icons.folder_outlined,
      title: l.projectsEmptyTitle,
      message: l.projectsEmptyMessage,
      action: widget.env.canCreate
          ? FilledButton.icon(
              onPressed: () => unawaited(_create()),
              icon: const Icon(Icons.add),
              label: Text(l.projectNew),
            )
          : null,
    );
  }

  List<Widget> _section(BuildContext context, ProjectSection s) {
    final l = AppLocalizations.of(context);
    final group = s.group;
    final collapsed = group != null && _c.isCollapsed(group.id);
    return [
      InkWell(
        key: ValueKey('group-header-${group?.id ?? 'none'}'),
        onTap: group == null ? null : () => _c.toggleGroup(group.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Icon(
                collapsed
                    ? (Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left
                          : Icons.chevron_right)
                    : Icons.expand_more,
                size: 20,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  group?.name ?? l.projectsUngrouped,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(toPersianDigits(s.projects.length)),
            ],
          ),
        ),
      ),
      if (!collapsed)
        for (final p in s.projects)
          Padding(
            key: ValueKey('project-${p.id}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: ProjectCard(project: p, onTap: () => unawaited(_open(p.id))),
          ),
    ];
  }
}
