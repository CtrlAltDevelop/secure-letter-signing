import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letters_env.dart' show showError;
import 'package:letter_signing/meetings/attendee_editor.dart';
import 'package:letter_signing/meetings/meeting_ui.dart';
import 'package:letter_signing/meetings/meetings_env.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/jalali_date_field.dart';

/// Create (when [meeting] is null) or edit a draft/scheduled meeting. Pops the saved
/// [MeetingOut].
class MeetingFormScreen extends StatefulWidget {
  const MeetingFormScreen({
    super.key,
    required this.env,
    this.meeting,
    this.customerId,
  });
  final MeetingsEnv env;
  final MeetingOut? meeting;

  /// Links the new meeting to this customer file.
  final String? customerId;

  @override
  State<MeetingFormScreen> createState() => _MeetingFormState();
}

class _MeetingFormState extends State<MeetingFormScreen> {
  late final _title = TextEditingController(text: widget.meeting?.title);
  late final _location = TextEditingController(
    text: widget.meeting?.brief.location,
  );
  late final _description = TextEditingController(
    text: widget.meeting?.description,
  );
  late MeetingDraft _draft = widget.meeting == null
      ? MeetingDraft(
          customerId: widget.customerId,
          attendees: [
            AttendeeDraft(userId: widget.env.userId, role: AttendeeRole.chair),
          ],
        )
      : MeetingDraft.fromMeeting(widget.meeting!);
  List<UserRef> _directory = const [];
  List<ProjectBrief> _projects = const [];
  List<MeetingTemplate> _templates = const [];
  bool _submitted = false;
  bool _saving = false;

  bool get _editing => widget.meeting != null;
  MeetingsEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLookups());
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    final dir = await env.directory();
    List<ProjectBrief> projects = const [];
    List<MeetingTemplate> templates = const [];
    try {
      projects = await env.projects.list(status: 'active');
    } on Object {
      // The project field just stays empty.
    }
    try {
      templates = await env.api.templates();
    } on Object {
      // Templates are optional.
    }
    if (!mounted) return;
    setState(() {
      _directory = dir;
      _projects = projects;
      _templates = templates;
    });
  }

  /// The draft with the text fields folded in.
  MeetingDraft _current() => _draft.copyWith(
    title: _title.text,
    location: _location.text,
    description: _description.text,
  );

  void _update(MeetingDraft Function(MeetingDraft d) change) =>
      setState(() => _draft = change(_current()));

  void _applyTemplate(MeetingTemplate t) {
    _location.text = t.location;
    _description.text = t.description;
    setState(() {
      _draft = _current().copyWith(
        kind: t.kind,
        attendees: t.attendees,
        templateId: t.id,
      );
      if (_title.text.trim().isEmpty) _title.text = t.name;
    });
  }

  String? _issueText(AppLocalizations l, MeetingIssue issue) => switch (issue) {
    MeetingIssue.titleMissing => l.meetingTitleRequired,
    MeetingIssue.startMissing => l.meetingStartRequired,
    MeetingIssue.endBeforeStart => l.meetingEndBeforeStart,
    MeetingIssue.needOneChair => l.meetingNeedChair,
    MeetingIssue.needOneSecretary => l.meetingNeedSecretary,
  };

  Future<void> _save({required bool schedule}) async {
    final draft = _current();
    setState(() {
      _draft = draft;
      _submitted = true;
    });
    if (draft.issues(schedule: schedule).isNotEmpty) return;
    setState(() => _saving = true);
    try {
      final saved = await _send(draft, schedule: schedule);
      if (mounted) Navigator.of(context).pop(saved);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showError(context, e);
    }
  }

  Future<MeetingOut> _send(MeetingDraft draft, {required bool schedule}) async {
    final existing = widget.meeting;
    if (existing == null) {
      return env.api.create(draft, schedule: schedule);
    }
    var saved = await env.api.patch(existing.id, draft.toPatchJson());
    saved = await env.api.setAttendees(existing.id, draft.attendees);
    if (schedule && saved.status == MeetingStatus.draft) {
      saved = await env.api.transition(existing.id, 'schedule');
    }
    return saved;
  }

  Future<void> _saveTemplate() async {
    final l = AppLocalizations.of(context);
    final draft = _current();
    final picked = await showDialog<_TemplateChoice>(
      context: context,
      builder: (_) =>
          _TemplateDialog(initialName: draft.title, canOrg: env.isManager),
    );
    if (picked == null || picked.name.isEmpty || !mounted) return;
    try {
      final t = await env.api.createTemplate(
        name: picked.name,
        scope: picked.org ? 'org' : 'personal',
        data: MeetingTemplate.dataJson(
          kind: draft.kind,
          location: draft.location,
          description: draft.description,
          attendees: draft.attendees,
        ),
      );
      if (!mounted) return;
      setState(() => _templates = [..._templates, t]);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.meetingTemplateSaved)));
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _kindPicker(AppLocalizations l) => SegmentedButton<String>(
    showSelectedIcon: false,
    segments: [
      for (final k in MeetingKind.all)
        ButtonSegment(value: k, label: Text(meetingKindLabel(l, k))),
    ],
    selected: {_draft.kind},
    onSelectionChanged: (v) => _update((d) => d.copyWith(kind: v.first)),
  );

  Widget _templatePicker(AppLocalizations l) {
    if (_templates.isEmpty || _editing) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        initialValue: _draft.templateId,
        decoration: InputDecoration(labelText: l.meetingTemplate),
        items: [
          for (final t in _templates)
            DropdownMenuItem(value: t.id, child: Text(t.name)),
        ],
        onChanged: (id) {
          final t = _templates.where((x) => x.id == id).firstOrNull;
          if (t != null) _applyTemplate(t);
        },
      ),
    );
  }

  Widget _projectPicker(AppLocalizations l) {
    if (_projects.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String?>(
        initialValue: _draft.projectId,
        decoration: InputDecoration(labelText: l.meetingProject),
        items: [
          DropdownMenuItem(value: null, child: Text(l.meetingNoProject)),
          for (final p in _projects)
            DropdownMenuItem(value: p.id, child: Text(p.name)),
        ],
        onChanged: (id) => _update(
          (d) => id == null
              ? d.copyWith(clearProject: true)
              : d.copyWith(projectId: id),
        ),
      ),
    );
  }

  Widget _dates(AppLocalizations l) => Column(
    children: [
      const SizedBox(height: 12),
      JalaliDateField(
        label: l.meetingStart,
        value: _draft.startsAt,
        withTime: true,
        onChanged: (d) => _update(
          (x) => d == null
              ? x.copyWith(clearStart: true)
              : x.copyWith(startsAt: d),
        ),
      ),
      const SizedBox(height: 12),
      JalaliDateField(
        label: l.meetingEnd,
        value: _draft.endsAt,
        withTime: true,
        onChanged: (d) => _update(
          (x) => d == null ? x.copyWith(clearEnd: true) : x.copyWith(endsAt: d),
        ),
      ),
    ],
  );

  String? _errorFor(
    AppLocalizations l,
    Set<MeetingIssue> issues,
    Iterable<MeetingIssue> mine,
  ) {
    if (!_submitted) return null;
    for (final i in mine) {
      if (issues.contains(i)) return _issueText(l, i);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final issues = _current().issues(schedule: true);
    final canSchedule =
        !_editing || widget.meeting!.status == MeetingStatus.draft;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? l.meetingEdit : l.meetingNew)),
      body: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _templatePicker(l),
                _kindPicker(l),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: l.meetingFieldTitle,
                    errorText: _errorFor(l, issues, [
                      MeetingIssue.titleMissing,
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _location,
                  decoration: InputDecoration(labelText: l.meetingLocation),
                ),
                _dates(l),
                if (_submitted && issues.contains(MeetingIssue.endBeforeStart))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l.meetingEndBeforeStart,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (_submitted && issues.contains(MeetingIssue.startMissing))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l.meetingStartRequired,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l.meetingDescription,
                    alignLabelWithHint: true,
                  ),
                ),
                _projectPicker(l),
                const SizedBox(height: 16),
                AttendeeEditor(
                  directory: _directory,
                  attendees: _draft.attendees,
                  onChanged: (a) => _update((d) => d.copyWith(attendees: a)),
                  errorText: _errorFor(l, issues, [
                    MeetingIssue.needOneChair,
                    MeetingIssue.needOneSecretary,
                  ]),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => unawaited(_saveTemplate()),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(l.meetingSaveTemplate),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (!_editing)
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => unawaited(_save(schedule: false)),
                        child: Text(l.meetingSaveDraft),
                      ),
                    FilledButton(
                      onPressed: _saving
                          ? null
                          : () => unawaited(_save(schedule: canSchedule)),
                      child: Text(
                        canSchedule ? l.meetingSaveSchedule : l.commonSave,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateChoice {
  const _TemplateChoice(this.name, this.org);
  final String name;
  final bool org;
}

class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({required this.initialName, required this.canOrg});
  final String initialName;
  final bool canOrg;

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  bool _org = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.meetingSaveTemplate),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l.meetingTemplateName),
          ),
          if (widget.canOrg)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.meetingTemplateOrg),
              value: _org,
              onChanged: (v) => setState(() => _org = v),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _TemplateChoice(_name.text.trim(), _org)),
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
