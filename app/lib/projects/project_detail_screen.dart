import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/bookmarks/pin_button.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show SkeletonList;
import 'package:letter_signing/polls/polls_env.dart';
import 'package:letter_signing/polls/polls_section.dart';
import 'package:letter_signing/projects/board_view.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/project_calendar_view.dart';
import 'package:letter_signing/projects/project_controller.dart';
import 'package:letter_signing/projects/project_files_view.dart';
import 'package:letter_signing/projects/project_form_screen.dart';
import 'package:letter_signing/projects/project_list_view.dart';
import 'package:letter_signing/projects/project_settings_view.dart';
import 'package:letter_signing/projects/project_ui.dart';
import 'package:letter_signing/projects/project_views_controller.dart';
import 'package:letter_signing/projects/projects_env.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/task_detail_screen.dart';
import 'package:letter_signing/tasks/task_form_screen.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/coming_soon_screen.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome;

/// One project with tabs: Board, List, Calendar, Files, Members/settings and a chat
/// placeholder. Opening it marks the project as seen (done by the board request).
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({
    super.key,
    required this.env,
    required this.projectId,
  });

  final ProjectsEnv env;
  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

enum _Tab { board, list, calendar, gantt, files, members, chat }

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late final ProjectController _project = ProjectController(
    env: widget.env,
    projectId: widget.projectId,
  );
  late final ProjectListController _list = ProjectListController(
    widget.env,
    widget.projectId,
  );
  late final ProjectCalendarController _calendar = ProjectCalendarController(
    widget.env,
    widget.projectId,
  );
  late final ProjectFilesController _files = ProjectFilesController(
    widget.env,
    widget.projectId,
  );

  /// Built once; null while the `gantt` module is off, which also drops the tab.
  late final Widget? _gantt = widget.env.ganttTab?.call(widget.projectId);
  late final List<_Tab> _order = [
    for (final t in _Tab.values)
      if (t != _Tab.gantt || _gantt != null) t,
  ];
  late final TabController _tabs = TabController(
    length: _order.length,
    vsync: this,
  )..addListener(_onTab);
  List<LabelInfo> _labels = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_project.load());
    unawaited(_loadLabels());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _project.dispose();
    _list.dispose();
    _calendar.dispose();
    _files.dispose();
    super.dispose();
  }

  Future<void> _loadLabels() async {
    final labels = await widget.env.tasks.labels();
    if (mounted) setState(() => _labels = labels);
  }

  /// Loads a tab's data the first time it is shown.
  void _onTab() {
    if (_tabs.indexIsChanging) return;
    switch (_order[_tabs.index]) {
      case _Tab.list when !_list.loaded && !_list.loading:
        unawaited(_list.load());
      case _Tab.calendar when !_calendar.loaded && !_calendar.loading:
        unawaited(_calendar.load());
      case _Tab.files when !_files.loaded && !_files.loading:
        unawaited(_files.load());
      default:
    }
  }

  Future<void> _openTask(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(env: widget.env.tasks, taskId: id),
      ),
    );
    if (!mounted) return;
    unawaited(_project.reloadBoard());
    unawaited(_list.load());
    unawaited(_calendar.load());
  }

  Future<void> _newTask(ProjectOut project) async {
    final todo = project.columns
        .where((c) => c.kind == ColumnKind.todo)
        .firstOrNull;
    final column = todo ?? project.columns.firstOrNull;
    final created = await Navigator.of(context).push<TaskOut>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          env: widget.env.tasks,
          initialProjectId: project.id,
          initialColumnId: column?.id,
        ),
      ),
    );
    if (created == null || !mounted) return;
    unawaited(_project.reloadBoard());
    await _openTask(created.id);
  }

  Future<void> _edit(ProjectOut project) async {
    final saved = await Navigator.of(context).push<ProjectOut>(
      MaterialPageRoute(
        builder: (_) => ProjectFormScreen(env: widget.env, project: project),
      ),
    );
    if (saved != null) await _project.load();
  }

  Future<void> _download(ProjectFile f) async {
    final api = widget.env.tasks.api.workspace;
    try {
      final bytes = await api.downloadFile(f.id);
      await widget.env.tasks.saveFile(
        bytes,
        name: f.name,
        mimeType: f.contentType,
      );
    } on Object catch (e) {
      if (mounted) reportOutcome(context, ActionOutcome.failed, e);
    }
  }

  void _copied(ProjectOut copy) {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.projectCopied(copy.name))));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _project,
    builder: (context, _) {
      final project = _project.project;
      return Scaffold(
        appBar: AppBar(
          title: Text(project?.name ?? '', overflow: TextOverflow.ellipsis),
          actions: [
            if (project != null)
              PinButton(
                api: widget.env.api.workspace,
                subjectId: project.subjectId,
              ),
            if (project != null)
              IconButton(
                key: const ValueKey('project-polls'),
                tooltip: AppLocalizations.of(context).pollsTitle,
                icon: const Icon(Icons.poll_outlined),
                onPressed: () => unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => PollsScreen(
                        env: PollsEnv.of(
                          widget.env.api.workspace,
                          widget.env.live,
                          widget.env.userId,
                        ),
                        targetSubjectId: project.subjectId,
                      ),
                    ),
                  ),
                ),
              ),
            if (project != null &&
                project.can.createTask &&
                !project.isArchived)
              IconButton(
                key: const ValueKey('project-new-task'),
                tooltip: AppLocalizations.of(context).taskNew,
                icon: const Icon(Icons.add_task),
                onPressed: () => unawaited(_newTask(project)),
              ),
          ],
          bottom: project == null ? null : _tabBar(context),
        ),
        body: _body(context, project),
      );
    },
  );

  PreferredSizeWidget _tabBar(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TabBar(
      controller: _tabs,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(text: l.projectTabBoard),
        Tab(text: l.projectTabList),
        Tab(text: l.projectTabCalendar),
        if (_gantt != null) Tab(text: l.projectTabGantt),
        Tab(text: l.projectTabFiles),
        Tab(text: l.projectTabMembers),
        Tab(text: l.projectTabChat),
      ],
    );
  }

  Widget _body(BuildContext context, ProjectOut? project) {
    final l = AppLocalizations.of(context);
    if (project == null) {
      if (_project.error != null) {
        return EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l.projectLoadFailed,
          message: '${_project.error}',
          action: OutlinedButton.icon(
            onPressed: () => unawaited(_project.load()),
            icon: const Icon(Icons.refresh),
            label: Text(l.commonRetry),
          ),
        );
      }
      return const SkeletonList(count: 3);
    }
    return TabBarView(
      controller: _tabs,
      children: [
        BoardView(
          controller: _project,
          labels: _labels,
          onOpenTask: (id) => unawaited(_openTask(id)),
        ),
        ProjectListView(
          controller: _list,
          onOpenTask: (id) => unawaited(_openTask(id)),
        ),
        ProjectCalendarView(
          controller: _calendar,
          labels: _labels,
          onOpenTask: (id) => unawaited(_openTask(id)),
        ),
        ?_gantt,
        ProjectFilesView(
          controller: _files,
          onDownload: (f) => unawaited(_download(f)),
          onOpenTask: (id) => unawaited(_openTask(id)),
        ),
        ProjectSettingsView(
          controller: _project,
          onEdit: () => unawaited(_edit(project)),
          onCopied: _copied,
        ),
        widget.env.chatTab?.call(widget.projectId) ??
            const ComingSoonScreen(icon: Icons.chat_bubble_outline),
      ],
    );
  }
}
