import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/jalali_date_field.dart';
import 'package:letter_signing/workspace/widgets/people_picker.dart';

Tone _resolutionTone(String status) => switch (status) {
  'done' => Tone.ok,
  'cancelled' => Tone.error,
  _ => Tone.info,
};

String _resolutionLabel(AppLocalizations l, String status) => switch (status) {
  'done' => l.resolutionDone,
  'cancelled' => l.resolutionCancelled,
  _ => l.resolutionOpen,
};

/// What the resolution sheet returns.
class ResolutionInput {
  const ResolutionInput({
    required this.text,
    required this.ownerIds,
    this.dueAt,
  });
  final String text;
  final List<int> ownerIds;
  final DateTime? dueAt;
}

/// The resolutions of the minutes: owners, due date, status (mirrors the linked task) and a chip
/// that opens the follow-up task.
class ResolutionsSection extends StatelessWidget {
  const ResolutionsSection({
    super.key,
    required this.meeting,
    required this.directory,
    required this.onAdd,
    required this.onEdit,
    required this.onDeactivate,
    required this.onOpenTask,
  });
  final MeetingOut meeting;
  final List<UserRef> directory;
  final VoidCallback onAdd;
  final void Function(Resolution r) onEdit;
  final void Function(Resolution r) onDeactivate;
  final void Function(String taskId) onOpenTask;

  bool get _canEdit =>
      meeting.can.record &&
      meeting.status != MeetingStatus.closed &&
      meeting.status != MeetingStatus.cancelled;

  String _owner(int id) {
    for (final u in directory) {
      if (u.id == id) return u.displayName;
    }
    for (final a in meeting.attendees) {
      if (a.user?.id == id) return a.displayName;
    }
    return '#$id';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          l.meetingResolutions,
          trailing: _canEdit
              ? TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l.resolutionAdd),
                )
              : null,
        ),
        if (meeting.resolutions.isEmpty)
          AppCard(child: Text(l.meetingNoResolutions))
        else
          for (final r in meeting.resolutions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ResolutionCard(
                resolution: r,
                owners: [for (final id in r.ownerIds) _owner(id)],
                canEdit: _canEdit,
                onEdit: () => onEdit(r),
                onDeactivate: () => onDeactivate(r),
                onOpenTask: onOpenTask,
              ),
            ),
      ],
    );
  }
}

class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({
    required this.resolution,
    required this.owners,
    required this.canEdit,
    required this.onEdit,
    required this.onDeactivate,
    required this.onOpenTask,
  });
  final Resolution resolution;
  final List<String> owners;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final void Function(String taskId) onOpenTask;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12.5,
    );
    final r = resolution;
    final taskId = r.taskId;
    return AppCard(
      key: ValueKey('resolution-${r.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(r.text)),
              const SizedBox(width: 8),
              StatusPill(
                _resolutionLabel(l, r.status),
                tone: _resolutionTone(r.status),
              ),
              if (canEdit)
                PopupMenuButton<bool>(
                  tooltip: l.lettersMenu,
                  padding: EdgeInsets.zero,
                  onSelected: (edit) => edit ? onEdit() : onDeactivate(),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: true, child: Text(l.resolutionEdit)),
                    PopupMenuItem(
                      value: false,
                      child: Text(l.resolutionDeactivate),
                    ),
                  ],
                ),
            ],
          ),
          if (owners.isNotEmpty)
            Text('${l.resolutionOwners}: ${owners.join('، ')}', style: muted),
          if (r.dueAt != null)
            Text(
              '${l.resolutionDue}: ${formatJalaliDate(r.dueAt!)}',
              style: muted,
            ),
          if (taskId != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ActionChip(
                avatar: const Icon(Icons.task_alt, size: 18),
                label: Text(
                  r.taskProgress == null
                      ? l.resolutionTask
                      : '${l.resolutionTask} (${toPersianDigits(r.taskProgress!)}٪)',
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => onOpenTask(taskId),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens the add/edit sheet; resolves to the input, or null when dismissed.
Future<ResolutionInput?> showResolutionSheet(
  BuildContext context, {
  required List<UserRef> directory,
  Resolution? initial,
}) => showModalBottomSheet<ResolutionInput>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ResolutionSheet(directory: directory, initial: initial),
);

class _ResolutionSheet extends StatefulWidget {
  const _ResolutionSheet({required this.directory, this.initial});
  final List<UserRef> directory;
  final Resolution? initial;

  @override
  State<_ResolutionSheet> createState() => _ResolutionSheetState();
}

class _ResolutionSheetState extends State<_ResolutionSheet> {
  late final _text = TextEditingController(text: widget.initial?.text);
  late List<int> _owners = [...?widget.initial?.ownerIds];
  late DateTime? _due = widget.initial?.dueAt?.toLocal();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, inset + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _text,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l.resolutionText,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              PeoplePicker(
                label: l.resolutionOwners,
                directory: widget.directory,
                selectedIds: _owners,
                onChanged: (v) => setState(() => _owners = v),
              ),
              const SizedBox(height: 12),
              JalaliDateField(
                label: l.resolutionDue,
                value: _due,
                onChanged: (d) => setState(() => _due = d),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _text.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                        ResolutionInput(
                          text: _text.text.trim(),
                          ownerIds: _owners,
                          dueAt: _due,
                        ),
                      ),
                child: Text(l.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
