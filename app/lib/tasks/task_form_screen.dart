import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/project_target_picker.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/task_labels.dart';
import 'package:letter_signing/tasks/tasks_api.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/jalali_date_field.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';
import 'package:letter_signing/workspace/widgets/label_create_sheet.dart';
import 'package:letter_signing/workspace/widgets/people_picker.dart';

/// Create (when [task] is null) or edit a task. Pops with the saved [TaskOut]. A new task can
/// start in a project: pass [initialProjectId] (and [initialColumnId]) or pick one in the form.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.env,
    this.task,
    this.initialProjectId,
    this.initialColumnId,
    this.initialDraft,
  });
  final TasksEnv env;
  final TaskOut? task;
  final String? initialProjectId;
  final int? initialColumnId;

  /// Prefill of a new task (e.g. created from a letter); ignored when editing.
  final TaskDraft? initialDraft;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final TextEditingController _title = TextEditingController(
    text: widget.task?.title ?? widget.initialDraft?.title,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.task?.description ?? widget.initialDraft?.description,
  );
  final _checklistInput = TextEditingController();
  late TaskDraft _draft = widget.task == null
      ? (widget.initialDraft ?? const TaskDraft()).copyWith(
          ownerIds: [widget.env.userId],
          projectId: widget.initialProjectId,
          columnId: widget.initialColumnId,
        )
      : TaskDraft.fromTask(widget.task!);
  List<UserRef> _directory = const [];

  /// Members of the chosen project: everyone on a project task must be one of them.
  List<UserRef>? _projectPeople;
  List<LabelInfo> _labels = const [];
  bool _submitted = false;
  bool _saving = false;

  bool get _editing => widget.task != null;

  /// People the task may be (re)assigned: only the creator-level editor changes them.
  bool get _canEditPeople => !_editing || widget.task!.can.edit;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLookups());
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _checklistInput.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    final dir = await widget.env.directory();
    final labels = await widget.env.labels();
    if (!mounted) return;
    setState(() {
      _directory = dir;
      _labels = labels;
    });
  }

  void _update(TaskDraft Function(TaskDraft d) change) =>
      setState(() => _draft = change(_draft));

  void _onProject(ProjectOut? project, int? columnId) {
    if (!mounted) return;
    setState(() {
      _projectPeople = project == null
          ? null
          : [for (final m in project.members) m.user];
      var draft = _draft.copyWith(clearProject: true);
      if (project != null) {
        draft = draft.copyWith(projectId: project.id, columnId: columnId);
        draft = _keepMembers(draft, {for (final u in _projectPeople!) u.id});
      }
      _draft = draft;
    });
  }

  /// Drops people who are not project members (the server would answer 422).
  TaskDraft _keepMembers(TaskDraft d, Set<int> members) {
    List<int> keep(List<int> ids) => [
      for (final id in ids)
        if (members.contains(id)) id,
    ];
    final owners = keep(d.ownerIds);
    return d.copyWith(
      ownerIds: owners.isEmpty && members.contains(widget.env.userId)
          ? [widget.env.userId]
          : owners,
      approverIds: keep(d.approverIds),
      followerIds: keep(d.followerIds),
    );
  }

  Future<void> _newLabel() async {
    final label = await showLabelCreateSheet(context, widget.env.api.workspace);
    if (label == null || !mounted) return;
    widget.env.invalidateLabels();
    final labels = await widget.env.labels();
    if (!mounted) return;
    setState(() {
      _labels = labels;
      _draft = _draft.copyWith(labelIds: [..._draft.labelIds, label.id]);
    });
  }

  DateTime _normalize(DateTime d) =>
      _draft.allDay ? DateTime(d.year, d.month, d.day) : d;

  void _setAllDay(bool on) => _update(
    (d) => d.copyWith(
      allDay: on,
      startAt: on && d.startAt != null ? _day(d.startAt!) : null,
      dueAt: on && d.dueAt != null ? _day(d.dueAt!) : null,
    ),
  );

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  void _addChecklist() {
    final text = _checklistInput.text.trim();
    if (text.isEmpty) return;
    _checklistInput.clear();
    _update((d) => d.copyWith(checklist: [...d.checklist, text]));
  }

  String? _issueText(AppLocalizations l, DraftIssue issue) {
    if (!_submitted || !_draft.issues.contains(issue)) return null;
    return switch (issue) {
      DraftIssue.titleMissing => l.formTitleRequired,
      DraftIssue.noOwner => l.formOwnerRequired,
      DraftIssue.dueBeforeStart => l.formDueBeforeStart,
    };
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_draft.issues.isNotEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await _persist();
      if (mounted) Navigator.of(context).pop(saved);
    } on ConflictException {
      if (mounted) _fail(AppLocalizations.of(context).taskConflict);
    } on Object catch (e) {
      _fail('$e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<TaskOut> _persist() async {
    final api = widget.env.api;
    final original = widget.task;
    if (original == null) return api.create(_draft);
    var task = original;
    final fields = _draft.patchAgainst(original);
    if (fields.isNotEmpty) {
      task = await api.patch(task.id, fields, version: task.version);
    }
    if (_canEditPeople && _draft.peopleChanged(original)) {
      task = await api.setPeople(
        task.id,
        ownerIds: _draft.ownerIds,
        approverIds: _draft.approverIds,
        followerIds: _draft.followerIds,
        version: task.version,
      );
    }
    if (!setEquals(_draft.labelIds.toSet(), original.labelIds.toSet())) {
      await api.workspace.setLabels(task.subjectId, _draft.labelIds);
    }
    return task;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l.taskEdit : l.taskNew),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => unawaited(_save()),
            child: Text(l.commonSave),
          ),
        ],
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            for (final w in _fields(l))
              Padding(padding: const EdgeInsets.only(bottom: 14), child: w),
          ],
        ),
      ),
    );
  }

  List<Widget> _fields(AppLocalizations l) => [
    TextField(
      key: const ValueKey('form-title'),
      controller: _title,
      maxLength: 200,
      decoration: InputDecoration(
        labelText: l.fieldTitle,
        errorText: _issueText(l, DraftIssue.titleMissing),
      ),
      onChanged: (v) => _update((d) => d.copyWith(title: v)),
    ),
    TextField(
      key: const ValueKey('form-description'),
      controller: _description,
      minLines: 3,
      maxLines: 8,
      decoration: InputDecoration(labelText: l.fieldDescription),
      onChanged: (v) => _update((d) => d.copyWith(description: v)),
    ),
    if (!_editing)
      ProjectTargetPicker(
        api: widget.env.projects,
        projectId: widget.initialProjectId,
        columnId: widget.initialColumnId,
        onChanged: _onProject,
      ),
    _priority(l),
    _dates(l),
    if (_canEditPeople) ..._people(l),
    if (!_editing) _checklist(l),
    _labelsField(l),
  ];

  Widget _priority(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l.fieldPriority, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        children: [
          for (final p in TaskPriority.all)
            ChoiceChip(
              label: Text(priorityLabel(l, p)),
              selected: _draft.priority == p,
              onSelected: (_) => _update((d) => d.copyWith(priority: p)),
            ),
        ],
      ),
    ],
  );

  Widget _dates(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      JalaliDateField(
        key: const ValueKey('form-start'),
        label: l.fieldStart,
        value: _draft.startAt,
        withTime: !_draft.allDay,
        onChanged: (v) => _update(
          (d) => v == null
              ? d.copyWith(clearStart: true)
              : d.copyWith(startAt: _normalize(v)),
        ),
      ),
      const SizedBox(height: 12),
      JalaliDateField(
        key: const ValueKey('form-due'),
        label: l.fieldDue,
        value: _draft.dueAt,
        withTime: !_draft.allDay,
        onChanged: (v) => _update(
          (d) => v == null
              ? d.copyWith(clearDue: true)
              : d.copyWith(dueAt: _normalize(v)),
        ),
      ),
      if (_issueText(l, DraftIssue.dueBeforeStart) != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _issueText(l, DraftIssue.dueBeforeStart)!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.fieldAllDay),
        value: _draft.allDay,
        onChanged: _setAllDay,
      ),
    ],
  );

  List<Widget> _people(AppLocalizations l) {
    final known = [
      UserRef(id: widget.env.userId, fullName: widget.env.userName),
      ...?widget.task?.owners,
      for (final a in widget.task?.approvers ?? <ApproverInfo>[]) a.user,
      ...?widget.task?.followers,
    ];
    PeoplePicker picker(
      String label,
      List<int> ids,
      TaskDraft Function(TaskDraft, List<int>) apply, {
      String? error,
    }) => PeoplePicker(
      label: label,
      directory: _projectPeople ?? _directory,
      known: known,
      selectedIds: ids,
      errorText: error,
      onChanged: (v) => _update((d) => apply(d, v)),
    );
    return [
      picker(
        l.fieldOwners,
        _draft.ownerIds,
        (d, v) => d.copyWith(ownerIds: v),
        error: _issueText(l, DraftIssue.noOwner),
      ),
      picker(
        l.fieldApprovers,
        _draft.approverIds,
        (d, v) => d.copyWith(approverIds: v),
      ),
      picker(
        l.fieldFollowers,
        _draft.followerIds,
        (d, v) => d.copyWith(followerIds: v),
      ),
    ];
  }

  Widget _checklist(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(l.fieldChecklist, style: Theme.of(context).textTheme.labelLarge),
      for (final (i, text) in _draft.checklist.indexed)
        ListTile(
          key: ValueKey('new-item-$i'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.check_box_outline_blank),
          title: Text(text),
          trailing: IconButton(
            tooltip: l.checklistRemove,
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _update(
              (d) => d.copyWith(
                checklist: [
                  for (final (j, c) in d.checklist.indexed)
                    if (j != i) c,
                ],
              ),
            ),
          ),
        ),
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('form-checklist-input'),
              controller: _checklistInput,
              decoration: InputDecoration(hintText: l.checklistAddHint),
              onSubmitted: (_) => _addChecklist(),
            ),
          ),
          IconButton(
            tooltip: l.checklistAdd,
            icon: const Icon(Icons.add),
            onPressed: _addChecklist,
          ),
        ],
      ),
    ],
  );

  Widget _labelsField(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l.labelsTitle, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      LabelChips(
        labels: _labels,
        selected: _draft.labelIds.toSet(),
        onChanged: (s) => _update((d) => d.copyWith(labelIds: s.toList())),
        onCreate: () => unawaited(_newLabel()),
      ),
    ],
  );
}
