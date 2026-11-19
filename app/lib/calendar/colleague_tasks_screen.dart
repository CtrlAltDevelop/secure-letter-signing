import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/calendar/calendar_env.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/task_card.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/open_target.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// A colleague's active tasks (`GET /tasks/of/{user_id}`, needs `monitor.view`): pick the
/// person, then switch between "what they must do" and "what they follow".
class ColleagueTasksScreen extends StatefulWidget {
  const ColleagueTasksScreen({super.key, required this.env});
  final CalendarEnv env;

  @override
  State<ColleagueTasksScreen> createState() => _ColleagueTasksScreenState();
}

class _ColleagueTasksScreenState extends State<ColleagueTasksScreen> {
  List<UserRef> _people = const [];
  UserRef? _person;
  String _box = 'inbox';
  List<TaskBrief> _tasks = const [];
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPeople());
  }

  Future<void> _loadPeople() async {
    final people = await widget.env.tasks.directory();
    if (mounted) setState(() => _people = people);
  }

  Future<void> _load() async {
    final p = _person;
    if (p == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await widget.env.api.tasksOf(p.id, box: _box);
      if (mounted && p == _person) _tasks = tasks;
    } on Object catch (e) {
      _error = e;
      _tasks = const [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.calendarColleagues)),
      body: PageBody(
        child: Column(
          children: [
            DropdownButtonFormField<UserRef>(
              key: const ValueKey('colleague-picker'),
              initialValue: _person,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.calendarFilterPerson),
              items: [
                for (final u in _people)
                  DropdownMenuItem(value: u, child: Text(u.displayName)),
              ],
              onChanged: (u) {
                _person = u;
                unawaited(_load());
              },
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'inbox', label: Text(l.tasksTabInbox)),
                ButtonSegment(
                  value: 'followup',
                  label: Text(l.tasksTabFollowup),
                ),
              ],
              selected: {_box},
              onSelectionChanged: (s) {
                _box = s.first;
                unawaited(_load());
              },
            ),
            Expanded(child: _list(context, l)),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, AppLocalizations l) {
    if (_person == null) {
      return EmptyState(
        icon: Icons.person_search_outlined,
        title: l.calendarPickPerson,
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    final e = _error;
    if (e != null) {
      return EmptyState(
        icon: Icons.lock_outline,
        title: e is ForbiddenException
            ? l.calendarMonitorForbidden
            : l.calendarLoadFailed,
      );
    }
    if (_tasks.isEmpty) {
      return EmptyState(icon: Icons.task_alt, title: l.calendarColleagueEmpty);
    }
    return ListView(
      children: [
        for (final t in _tasks)
          Padding(
            key: ValueKey('colleague-task-${t.id}'),
            padding: const EdgeInsets.only(bottom: 8),
            child: TaskCard(
              task: t,
              labels: const [],
              onTap: () => unawaited(
                widget.env.open(
                  context,
                  OpenTarget(
                    module: 'tasks',
                    kind: 'task',
                    id: t.id,
                    subjectId: t.subjectId,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
