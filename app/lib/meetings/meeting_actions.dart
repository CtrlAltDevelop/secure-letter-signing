import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/meetings/models.dart';

/// Lifecycle and tool buttons of a meeting, shown according to the status and `can` flags.
class MeetingActionBar extends StatelessWidget {
  const MeetingActionBar({
    super.key,
    required this.meeting,
    required this.busy,
    required this.onAction,
    required this.onRemind,
    required this.onSms,
  });
  final MeetingOut meeting;
  final bool busy;

  /// `schedule`, `hold`, `close`, `reopen` or `cancel`.
  final void Function(String action) onAction;
  final VoidCallback onRemind;
  final VoidCallback onSms;

  /// The buttons to show, as (action, label key) in display order.
  static List<String> actionsFor(MeetingOut m) {
    final c = m.can;
    final signed = m.currentSignatures.isNotEmpty;
    return [
      if (m.status == MeetingStatus.draft && c.manage) 'schedule',
      if (m.status == MeetingStatus.scheduled && c.chair) 'hold',
      if (m.status == MeetingStatus.held && c.chair) 'close',
      if (c.chair &&
          (m.status == MeetingStatus.closed ||
              (m.status == MeetingStatus.held && signed)))
        'reopen',
      if ((m.status == MeetingStatus.draft ||
              m.status == MeetingStatus.scheduled) &&
          c.manage)
        'cancel',
    ];
  }

  bool get _canRemind =>
      meeting.can.record && meeting.status == MeetingStatus.scheduled;

  bool get _canSms =>
      meeting.can.run &&
      (meeting.status == MeetingStatus.scheduled ||
          meeting.status == MeetingStatus.held);

  String _label(AppLocalizations l, String action) => switch (action) {
    'schedule' => l.meetingActionSchedule,
    'hold' => l.meetingActionHold,
    'close' => l.meetingActionClose,
    'reopen' => l.meetingActionReopen,
    _ => l.meetingActionCancel,
  };

  IconData _icon(String action) => switch (action) {
    'schedule' => Icons.event_available_outlined,
    'hold' => Icons.play_circle_outline,
    'close' => Icons.lock_outline,
    'reopen' => Icons.lock_open_outlined,
    _ => Icons.event_busy_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final actions = actionsFor(meeting);
    if (actions.isEmpty && !_canRemind && !_canSms) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in actions)
          (a == 'cancel' || a == 'reopen'
              ? OutlinedButton.icon(
                  key: ValueKey('action-$a'),
                  onPressed: busy ? null : () => onAction(a),
                  icon: Icon(_icon(a)),
                  label: Text(_label(l, a)),
                )
              : FilledButton.icon(
                  key: ValueKey('action-$a'),
                  onPressed: busy ? null : () => onAction(a),
                  icon: Icon(_icon(a)),
                  label: Text(_label(l, a)),
                )),
        if (_canRemind)
          OutlinedButton.icon(
            key: const ValueKey('action-remind'),
            onPressed: busy ? null : onRemind,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(l.meetingRemind),
          ),
        if (_canSms)
          OutlinedButton.icon(
            key: const ValueKey('action-sms'),
            onPressed: busy ? null : onSms,
            icon: const Icon(Icons.sms_outlined),
            label: Text(l.meetingSms),
          ),
      ],
    );
  }
}

const _offsets = [15, 30, 60, 180, 1440];

/// Asks how long before the start attendees are reminded; resolves to minutes, or null.
Future<int?> showRemindDialog(BuildContext context) =>
    showDialog<int>(context: context, builder: (_) => const _RemindDialog());

class _RemindDialog extends StatefulWidget {
  const _RemindDialog();

  @override
  State<_RemindDialog> createState() => _RemindDialogState();
}

class _RemindDialogState extends State<_RemindDialog> {
  int _offset = 60;

  String _label(AppLocalizations l, int minutes) => minutes >= 1440
      ? l.meetingOffsetDays(toPersianDigits(minutes ~/ 1440))
      : minutes >= 60
      ? l.meetingOffsetHours(toPersianDigits(minutes ~/ 60))
      : l.meetingOffsetMinutes(toPersianDigits(minutes));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.meetingRemindTitle),
      content: DropdownButtonFormField<int>(
        initialValue: _offset,
        decoration: InputDecoration(labelText: l.meetingRemindBefore),
        items: [
          for (final o in _offsets)
            DropdownMenuItem(value: o, child: Text(_label(l, o))),
        ],
        onChanged: (v) => setState(() => _offset = v ?? _offset),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _offset),
          child: Text(l.commonConfirm),
        ),
      ],
    );
  }
}

/// Asks for the SMS text; resolves to it, or null when cancelled.
Future<String?> showSmsDialog(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _SmsDialog());

class _SmsDialog extends StatefulWidget {
  const _SmsDialog();

  @override
  State<_SmsDialog> createState() => _SmsDialogState();
}

class _SmsDialogState extends State<_SmsDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final empty = _text.text.trim().isEmpty;
    return AlertDialog(
      title: Text(l.meetingSmsTitle),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLines: 4,
        maxLength: 500,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: l.meetingSmsText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: empty
              ? null
              : () => Navigator.pop(context, _text.text.trim()),
          child: Text(l.meetingSmsSend),
        ),
      ],
    );
  }
}
