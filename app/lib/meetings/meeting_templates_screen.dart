import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letters_env.dart' show showError;
import 'package:letter_signing/meetings/meeting_ui.dart';
import 'package:letter_signing/meetings/meetings_env.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Manages the meeting templates the user can see: rename, deactivate and reactivate.
class MeetingTemplatesScreen extends StatefulWidget {
  const MeetingTemplatesScreen({super.key, required this.env});
  final MeetingsEnv env;

  @override
  State<MeetingTemplatesScreen> createState() => _TemplatesState();
}

class _TemplatesState extends State<MeetingTemplatesScreen> {
  List<MeetingTemplate>? _rows;
  Object? _error;

  MeetingsEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final rows = await env.api.templates(includeInactive: true);
      if (mounted) setState(() => _rows = rows);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  bool _canEdit(MeetingTemplate t) => t.scope == 'org'
      ? env.isManager
      : t.ownerId == null || t.ownerId == env.userId;

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
      await _load();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _rename(MeetingTemplate t) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: t.name),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await _run(() => env.api.patchTemplate(t.id, name: name));
  }

  Widget _row(MeetingTemplate t, AppLocalizations l) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final editable = _canEdit(t);
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      t.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    StatusPill(
                      t.scope == 'org'
                          ? l.meetingTemplateScopeOrg
                          : l.meetingTemplateScopePersonal,
                      tone: t.scope == 'org' ? Tone.info : Tone.neutral,
                    ),
                    if (!t.active)
                      StatusPill(l.meetingTemplateInactive, tone: Tone.warn),
                  ],
                ),
                Text(
                  '${meetingKindLabel(l, t.kind)}  -  '
                  '${l.meetingAttendeeCount(toPersianDigits(t.attendees.length))}',
                  style: muted,
                ),
              ],
            ),
          ),
          if (editable) ...[
            IconButton(
              tooltip: l.meetingTemplateRename,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => unawaited(_rename(t)),
            ),
            IconButton(
              tooltip: t.active
                  ? l.meetingTemplateDeactivate
                  : l.meetingTemplateActivate,
              icon: Icon(
                t.active
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => unawaited(
                _run(() => env.api.patchTemplate(t.id, active: !t.active)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: Text(l.meetingTemplatesTitle)),
      body: rows == null
          ? (_error != null
                ? EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: l.meetingsLoadFailed,
                    message: '$_error',
                  )
                : const Center(child: CircularProgressIndicator()))
          : rows.isEmpty
          ? EmptyState(
              icon: Icons.copy_all_outlined,
              title: l.meetingTemplatesEmpty,
              message: l.meetingTemplatesEmptyHint,
            )
          : ListView(
              children: [
                PageBody(
                  child: Column(
                    children: [
                      for (final t in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _row(t, l),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});
  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.meetingTemplateRename),
      content: TextField(
        controller: _name,
        decoration: InputDecoration(labelText: l.meetingTemplateName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _name.text.trim()),
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
