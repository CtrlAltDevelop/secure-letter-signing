import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show SkeletonList;
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/task_card.dart';
import 'package:letter_signing/tasks/task_detail_screen.dart';
import 'package:letter_signing/tasks/task_form_screen.dart';
import 'package:letter_signing/tasks/task_labels.dart';
import 'package:letter_signing/tasks/tasks_controller.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';

/// The Tasks module root: Inbox (my tasks), Follow-up and All, each with search, a status
/// filter and label filter, pull to refresh and live refresh.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.env});
  final TasksEnv env;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: TaskBox.values.length,
    vsync: this,
  )..addListener(_onTab);
  late final Map<String, TasksListController> _controllers = {
    for (final box in TaskBox.values)
      box: TasksListController(
        api: widget.env.api,
        live: widget.env.live,
        box: box,
      ),
  };
  List<LabelInfo> _labels = const [];

  @override
  void initState() {
    super.initState();
    _ensureLoaded(0);
    unawaited(_loadLabels());
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLabels() async {
    final labels = await widget.env.labels();
    if (mounted) setState(() => _labels = labels);
  }

  void _onTab() => _ensureLoaded(_tabs.index);

  void _ensureLoaded(int index) {
    final c = _controllers[TaskBox.values[index]]!;
    if (!c.loaded && !c.loading) unawaited(c.load());
  }

  Future<void> _refreshAll() async {
    for (final c in _controllers.values) {
      if (c.loaded) unawaited(c.refresh());
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<TaskOut>(
      MaterialPageRoute(builder: (_) => TaskFormScreen(env: widget.env)),
    );
    if (created == null || !mounted) return;
    unawaited(_refreshAll());
    await _open(created.id);
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(env: widget.env, taskId: id),
      ),
    );
    if (mounted) unawaited(_refreshAll());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: widget.env.canCreate
          ? FloatingActionButton.extended(
              onPressed: _create,
              tooltip: l.taskNew,
              icon: const Icon(Icons.add),
              label: Text(l.taskNew),
            )
          : null,
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: l.tasksTabInbox),
              Tab(text: l.tasksTabFollowup),
              Tab(text: l.tasksTabAll),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final box in TaskBox.values)
                  TaskBoxView(
                    key: PageStorageKey(box),
                    controller: _controllers[box]!,
                    labels: _labels,
                    onPickCustomer: widget.env.pickCustomer,
                    onOpen: _open,
                    onCreate: widget.env.canCreate ? _create : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tab: search field, filters and the paged list of a [TasksListController].
class TaskBoxView extends StatefulWidget {
  const TaskBoxView({
    super.key,
    required this.controller,
    required this.labels,
    required this.onOpen,
    this.onPickCustomer,
    this.onCreate,
  });

  final TasksListController controller;
  final List<LabelInfo> labels;
  final ValueChanged<String> onOpen;
  final VoidCallback? onCreate;
  final Future<({String id, String name})?> Function(BuildContext)?
  onPickCustomer;

  @override
  State<TaskBoxView> createState() => _TaskBoxViewState();
}

class _TaskBoxViewState extends State<TaskBoxView>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _search = TextEditingController(
    text: widget.controller.query,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _nearEnd(ScrollNotification n) {
    if (n.metrics.extentAfter < 300) unawaited(widget.controller.loadMore());
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => NotificationListener<ScrollNotification>(
        onNotification: _nearEnd,
        child: RefreshIndicator(
          onRefresh: c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.fromSTEB(
              Tokens.gap,
              8,
              Tokens.gap,
              96,
            ),
            children: [
              _searchField(context),
              const SizedBox(height: 8),
              _statusChips(context),
              if (widget.labels.isNotEmpty) ...[
                const SizedBox(height: 4),
                LabelChips(
                  labels: widget.labels,
                  selected: {?c.labelId},
                  single: true,
                  onChanged: (s) => unawaited(c.setLabel(s.firstOrNull)),
                ),
              ],
              if (widget.onPickCustomer != null) _customerChip(context),
              const SizedBox(height: 8),
              ..._body(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customerChip(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.controller;
    final active = c.customerId != null;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: InputChip(
        key: const ValueKey('tasks-customer-filter'),
        avatar: const Icon(Icons.business_center_outlined, size: 18),
        label: Text(
          active
              ? l.tasksFilterCustomerOf(c.customerName)
              : l.tasksFilterCustomer,
        ),
        selected: active,
        onPressed: () async {
          final picked = await widget.onPickCustomer!(context);
          if (picked != null) {
            await c.setCustomer(picked.id, name: picked.name);
          }
        },
        onDeleted: active ? () => unawaited(c.setCustomer(null)) : null,
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.controller;
    return TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: l.tasksSearchHint,
        suffixIcon: c.query.isEmpty
            ? null
            : IconButton(
                tooltip: l.tasksSearchClear,
                icon: const Icon(Icons.close),
                onPressed: () {
                  _search.clear();
                  unawaited(c.setQuery(''));
                },
              ),
      ),
      onSubmitted: (v) => unawaited(c.setQuery(v)),
    );
  }

  Widget _statusChips(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.controller;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final s in ['', ...TaskStatus.all])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(s.isEmpty ? l.tasksFilterAll : statusLabel(l, s)),
                selected: c.status == s,
                onSelected: (_) => unawaited(c.setStatus(s)),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.controller;
    if (c.loading && c.items.isEmpty) {
      return const [SizedBox(height: 360, child: SkeletonList(count: 3))];
    }
    if (c.error != null && c.items.isEmpty) {
      return [
        EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l.tasksLoadFailed,
          message: '${c.error}',
          action: OutlinedButton.icon(
            onPressed: () => unawaited(c.load()),
            icon: const Icon(Icons.refresh),
            label: Text(l.commonRetry),
          ),
        ),
      ];
    }
    if (c.items.isEmpty) return [_empty(context)];
    return [
      for (final t in c.items)
        Padding(
          key: ValueKey(t.id),
          padding: const EdgeInsets.only(bottom: Tokens.gap * 0.75),
          child: TaskCard(
            task: t,
            labels: widget.labels,
            onTap: () => widget.onOpen(t.id),
          ),
        ),
      if (c.loadingMore)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (c.hasMore)
        Center(
          child: TextButton(
            onPressed: () => unawaited(c.loadMore()),
            child: Text(l.tasksLoadMore),
          ),
        ),
    ];
  }

  Widget _empty(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.controller;
    if (c.filtered) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: l.tasksEmptyFilteredTitle,
        message: l.tasksEmptyFilteredMessage,
      );
    }
    final (title, message) = switch (c.box) {
      TaskBox.inbox => (l.tasksEmptyInboxTitle, l.tasksEmptyInboxMessage),
      TaskBox.followup => (
        l.tasksEmptyFollowupTitle,
        l.tasksEmptyFollowupMessage,
      ),
      _ => (l.tasksEmptyAllTitle, l.tasksEmptyAllMessage),
    };
    return EmptyState(
      icon: Icons.task_alt_outlined,
      title: title,
      message: message,
      action: widget.onCreate == null
          ? null
          : FilledButton.icon(
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add),
              label: Text(l.taskNew),
            ),
    );
  }
}
