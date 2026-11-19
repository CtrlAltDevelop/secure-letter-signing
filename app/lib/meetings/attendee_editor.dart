import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/meetings/meeting_ui.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/people_picker.dart';

/// Edits the attendee list: colleagues (from the directory) and external guests, each with a
/// role (chair, secretary, member, guest).
class AttendeeEditor extends StatelessWidget {
  const AttendeeEditor({
    super.key,
    required this.directory,
    required this.attendees,
    required this.onChanged,
    this.errorText,
  });

  final List<UserRef> directory;
  final List<AttendeeDraft> attendees;
  final ValueChanged<List<AttendeeDraft>> onChanged;
  final String? errorText;

  String _name(AttendeeDraft a) {
    if (a.userId == null) return a.guestName;
    for (final u in directory) {
      if (u.id == a.userId) return u.displayName;
    }
    return '#${a.userId}';
  }

  Future<void> _addPeople(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final current = [
      for (final a in attendees)
        if (a.userId != null) a.userId!,
    ];
    final picked = await showPeoplePickerSheet(
      context,
      title: l.meetingAttendees,
      directory: directory,
      selected: current,
    );
    if (picked == null) return;
    final byId = {
      for (final a in attendees)
        if (a.userId != null) a.userId!: a,
    };
    onChanged([
      for (final a in attendees)
        if (a.userId == null) a,
      for (final id in picked)
        byId[id] ?? AttendeeDraft(userId: id, role: AttendeeRole.member),
    ]);
  }

  Future<void> _addGuest(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _GuestDialog(),
    );
    if (name == null || name.isEmpty) return;
    onChanged([
      ...attendees,
      AttendeeDraft(guestName: name, role: AttendeeRole.guest),
    ]);
  }

  void _setRole(AttendeeDraft a, String role) => onChanged([
    for (final x in attendees)
      if (identical(x, a)) a.withRole(role) else x,
  ]);

  void _remove(AttendeeDraft a) => onChanged([
    for (final x in attendees)
      if (!identical(x, a)) x,
  ]);

  Widget _row(BuildContext context, AttendeeDraft a, AppLocalizations l) {
    return ListTile(
      key: ValueKey('attendee-${a.userId ?? a.guestName}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(a.userId == null ? Icons.person_outline : Icons.person),
      title: Text(_name(a), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: a.userId == null ? Text(l.meetingExternalGuest) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            tooltip: l.meetingFieldRole,
            onSelected: (r) => _setRole(a, r),
            itemBuilder: (_) => [
              for (final r in AttendeeRole.all)
                PopupMenuItem(value: r, child: Text(attendeeRoleLabel(l, r))),
            ],
            child: Chip(
              label: Text(attendeeRoleLabel(l, a.role)),
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton(
            tooltip: l.peopleRemove(_name(a)),
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _remove(a),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.meetingAttendees, style: Theme.of(context).textTheme.labelLarge),
        for (final a in attendees) _row(context, a, l),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: Text(l.meetingAddPeople),
              visualDensity: VisualDensity.compact,
              onPressed: () => unawaited(_addPeople(context)),
            ),
            ActionChip(
              avatar: const Icon(Icons.badge_outlined, size: 18),
              label: Text(l.meetingAddGuest),
              visualDensity: VisualDensity.compact,
              onPressed: () => unawaited(_addGuest(context)),
            ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorText!,
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _GuestDialog extends StatefulWidget {
  const _GuestDialog();

  @override
  State<_GuestDialog> createState() => _GuestDialogState();
}

class _GuestDialogState extends State<_GuestDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.meetingAddGuest),
      content: TextField(
        controller: _name,
        autofocus: true,
        decoration: InputDecoration(labelText: l.meetingGuestName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _name.text.trim()),
          child: Text(l.commonConfirm),
        ),
      ],
    );
  }
}
