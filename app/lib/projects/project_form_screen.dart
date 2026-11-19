import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/project_ui.dart';
import 'package:letter_signing/projects/projects_env.dart';
import 'package:letter_signing/tasks/tasks_api.dart' show ConflictException;
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/jalali_date_field.dart';
import 'package:letter_signing/workspace/widgets/people_picker.dart';

/// Create (when [project] is null) or edit a project. Pops with the saved [ProjectOut].
class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({super.key, required this.env, this.project});

  final ProjectsEnv env;
  final ProjectOut? project;

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  late final _name = TextEditingController(text: widget.project?.name);
  late final _description = TextEditingController(
    text: widget.project?.description,
  );
  late ProjectDraft _draft = widget.project == null
      ? ProjectDraft(
          members: [MemberDraft(widget.env.userId, ProjectRole.manager)],
        )
      : ProjectDraft.fromProject(widget.project!);
  List<UserRef> _directory = const [];
  List<ProjectGroup> _groups = const [];
  bool _submitted = false;
  bool _saving = false;

  bool get _editing => widget.project != null;

  /// The owner can neither leave nor be demoted (the server answers 422).
  int get _ownerId => widget.project?.ownerId ?? widget.env.userId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLookups());
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    final dir = await widget.env.directory();
    var groups = const <ProjectGroup>[];
    try {
      groups = await widget.env.api.groups();
    } on Object {
      // Groups are optional: the field just stays empty.
    }
    if (!mounted) return;
    setState(() {
      _directory = dir;
      _groups = groups;
    });
  }

  void _update(ProjectDraft Function(ProjectDraft d) change) =>
      setState(() => _draft = change(_draft));

  String? _issueText(AppLocalizations l, ProjectIssue issue) {
    if (!_submitted || !_draft.issues.contains(issue)) return null;
    return switch (issue) {
      ProjectIssue.nameMissing => l.projectNameRequired,
      ProjectIssue.endBeforeStart => l.projectEndBeforeStart,
    };
  }

  /// New picker selection: keeps roles of people already there, adds newcomers as members and
  /// keeps the owner as manager.
  void _setPeople(List<int> ids) {
    final roles = {for (final m in _draft.members) m.userId: m.role};
    final all = {_ownerId, ...ids};
    _update(
      (d) => d.copyWith(
        members: [
          for (final id in all)
            MemberDraft(
              id,
              id == _ownerId
                  ? ProjectRole.manager
                  : (roles[id] ?? ProjectRole.member),
            ),
        ],
      ),
    );
  }

  void _setRole(int userId, String role) => _update(
    (d) => d.copyWith(
      members: [
        for (final m in d.members)
          if (m.userId == userId) MemberDraft(userId, role) else m,
      ],
    ),
  );

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_draft.issues.isNotEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await _persist();
      if (mounted) Navigator.of(context).pop(saved);
    } on ConflictException {
      if (mounted) _fail(AppLocalizations.of(context).projectConflict);
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

  Future<ProjectOut> _persist() async {
    final api = widget.env.api;
    final original = widget.project;
    if (original == null) return api.create(_draft);
    var project = original;
    final fields = _draft.patchAgainst(original);
    if (fields.isNotEmpty) project = await api.patch(project.id, fields);
    if (_draft.membersChanged(original)) {
      project = await api.setMembers(project.id, _draft.members);
    }
    return project;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l.projectEdit : l.projectNew),
        actions: [
          TextButton(
            key: const ValueKey('project-save'),
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
      key: const ValueKey('project-name'),
      controller: _name,
      maxLength: 200,
      decoration: InputDecoration(
        labelText: l.projectName,
        errorText: _issueText(l, ProjectIssue.nameMissing),
      ),
      onChanged: (v) => _update((d) => d.copyWith(name: v)),
    ),
    TextField(
      key: const ValueKey('project-description'),
      controller: _description,
      minLines: 2,
      maxLines: 6,
      decoration: InputDecoration(labelText: l.fieldDescription),
      onChanged: (v) => _update((d) => d.copyWith(description: v)),
    ),
    if (_groups.isNotEmpty) _groupField(l),
    _colors(l),
    _dates(l),
    _members(l),
  ];

  Widget _groupField(AppLocalizations l) => DropdownButtonFormField<int?>(
    key: const ValueKey('project-group'),
    isExpanded: true,
    initialValue: _draft.groupId,
    decoration: InputDecoration(labelText: l.projectGroup),
    items: [
      DropdownMenuItem<int?>(value: null, child: Text(l.projectNone)),
      for (final g in _groups)
        DropdownMenuItem<int?>(
          value: g.id,
          child: Text(g.name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (id) => _update(
      (d) =>
          id == null ? d.copyWith(clearGroup: true) : d.copyWith(groupId: id),
    ),
  );

  Widget _colors(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l.projectColor, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          for (var i = 0; i < projectPalette.length; i++)
            InkResponse(
              key: ValueKey('color-$i'),
              onTap: () => _update((d) => d.copyWith(color: i)),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: projectPalette[i],
                  shape: BoxShape.circle,
                  border: _draft.color == i
                      ? Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                          width: 3,
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _dates(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      JalaliDateField(
        key: const ValueKey('project-start'),
        label: l.fieldStart,
        value: _draft.startDate,
        onChanged: (v) => _update(
          (d) => v == null
              ? d.copyWith(clearStart: true)
              : d.copyWith(startDate: v),
        ),
      ),
      const SizedBox(height: 12),
      JalaliDateField(
        key: const ValueKey('project-end'),
        label: l.projectEnd,
        value: _draft.endDate,
        onChanged: (v) => _update(
          (d) =>
              v == null ? d.copyWith(clearEnd: true) : d.copyWith(endDate: v),
        ),
      ),
      if (_issueText(l, ProjectIssue.endBeforeStart) != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _issueText(l, ProjectIssue.endBeforeStart)!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );

  Widget _members(AppLocalizations l) {
    final known = [
      UserRef(id: widget.env.userId),
      ...?widget.project?.owner == null ? null : [widget.project!.owner!],
      for (final m in widget.project?.members ?? <ProjectMember>[]) m.user,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PeoplePicker(
          label: l.projectMembers,
          directory: _directory,
          known: known,
          selectedIds: [for (final m in _draft.members) m.userId],
          onChanged: _setPeople,
        ),
        const SizedBox(height: 8),
        for (final m in _draft.members) _roleRow(l, m, known),
      ],
    );
  }

  Widget _roleRow(AppLocalizations l, MemberDraft m, List<UserRef> known) {
    final all = [..._directory, ...known];
    final name = all
        .where((u) => u.id == m.userId)
        .map((u) => u.displayName)
        .firstOrNull;
    final isOwner = m.userId == _ownerId;
    return Row(
      key: ValueKey('role-row-${m.userId}'),
      children: [
        Expanded(
          child: Text(
            name == null || name.isEmpty ? '#${m.userId}' : name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownButton<String>(
          key: ValueKey('role-${m.userId}'),
          value: m.role,
          items: [
            for (final r in ProjectRole.all)
              DropdownMenuItem(value: r, child: Text(projectRoleLabel(l, r))),
          ],
          onChanged: isOwner ? null : (r) => _setRole(m.userId, r ?? m.role),
        ),
      ],
    );
  }
}
