import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/people_picker.dart';

Tone _referralTone(String status) => switch (status) {
  ReferralInfo.done => Tone.ok,
  ReferralInfo.declined => Tone.error,
  _ => Tone.warn,
};

String _referralLabel(AppLocalizations l, String status) => switch (status) {
  ReferralInfo.done => l.referralDone,
  ReferralInfo.declined => l.referralDeclined,
  _ => l.referralPending,
};

/// Referrals of a letter: who it was sent to, their answers, a button to refer it further and
/// done/declined buttons for the referee. Loads itself; hidden when the server refuses (403).
class LetterReferralsSection extends StatefulWidget {
  const LetterReferralsSection({
    super.key,
    required this.env,
    required this.letterId,
    required this.canRefer,
    this.onChanged,
  });
  final LettersEnv env;
  final String letterId;

  /// The letter may be referred (not a draft or cancelled).
  final bool canRefer;
  final VoidCallback? onChanged;

  @override
  State<LetterReferralsSection> createState() => _ReferralsState();
}

class _ReferralsState extends State<LetterReferralsSection> {
  List<ReferralInfo>? _rows;
  bool _hidden = false;

  LettersEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final rows = await env.v2.referrals(widget.letterId);
      if (mounted) setState(() => _rows = rows);
    } on Object {
      if (mounted) setState(() => _hidden = true);
    }
  }

  Future<void> _refer() async {
    final l = AppLocalizations.of(context);
    final directory = await env.directory();
    if (!mounted) return;
    final result = await showModalBottomSheet<_ReferDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReferSheet(
        directory: [
          for (final u in directory)
            if (u.id != env.userId) u,
        ],
        title: l.referralSheetTitle,
      ),
    );
    if (result == null || !mounted) return;
    await _run(
      () => env.v2.refer(
        widget.letterId,
        userIds: result.userIds,
        note: result.note,
      ),
    );
  }

  Future<void> _respond(ReferralInfo r, String status) async {
    final l = AppLocalizations.of(context);
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(
        title: status == ReferralInfo.done
            ? l.referralMarkDone
            : l.referralMarkDeclined,
        label: l.referralNoteOptional,
        confirm: l.commonConfirm,
      ),
    );
    if (note == null || !mounted) return;
    await _run(() => env.v2.respond(r.id, status: status, note: note));
  }

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
      await _load();
      widget.onChanged?.call();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (_hidden || rows == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    if (rows.isEmpty && !widget.canRefer) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          l.referralTitle,
          trailing: widget.canRefer
              ? TextButton.icon(
                  onPressed: () => unawaited(_refer()),
                  icon: const Icon(Icons.forward_to_inbox_outlined, size: 18),
                  label: Text(l.referralRefer),
                )
              : null,
        ),
        if (rows.isEmpty)
          AppCard(child: Text(l.referralEmpty))
        else
          AppCard(
            child: Column(
              children: [
                for (final r in rows)
                  _ReferralRow(
                    referral: r,
                    mine: r.toUser.id == env.userId,
                    onRespond: (s) => unawaited(_respond(r, s)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReferralRow extends StatelessWidget {
  const _ReferralRow({
    required this.referral,
    required this.mine,
    required this.onRespond,
  });
  final ReferralInfo referral;
  final bool mine;
  final ValueChanged<String> onRespond;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12.5,
    );
    final r = referral;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PersonAvatar(r.toUser.displayName, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.referralFromTo(
                    r.fromUser.displayName,
                    r.toUser.displayName,
                  ),
                ),
              ),
              StatusPill(
                _referralLabel(l, r.status),
                tone: _referralTone(r.status),
              ),
            ],
          ),
          if (r.createdAt != null)
            Text(fmtDateTime(r.createdAt!), style: muted),
          if (r.note.isNotEmpty) Text('"${r.note}"'),
          if (r.responseNote.isNotEmpty)
            Text('${l.referralAnswer}: ${r.responseNote}', style: muted),
          if (mine && r.isPending)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => onRespond(ReferralInfo.done),
                  child: Text(l.referralMarkDone),
                ),
                TextButton(
                  onPressed: () => onRespond(ReferralInfo.declined),
                  child: Text(l.referralMarkDeclined),
                ),
              ],
            ),
          const Divider(height: 8),
        ],
      ),
    );
  }
}

class _ReferDraft {
  const _ReferDraft(this.userIds, this.note);
  final List<int> userIds;
  final String note;
}

class _ReferSheet extends StatefulWidget {
  const _ReferSheet({required this.directory, required this.title});
  final List<UserRef> directory;
  final String title;

  @override
  State<_ReferSheet> createState() => _ReferSheetState();
}

class _ReferSheetState extends State<_ReferSheet> {
  List<int> _ids = const [];
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
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
              PeoplePicker(
                label: widget.title,
                directory: widget.directory,
                selectedIds: _ids,
                onChanged: (v) => setState(() => _ids = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: l.referralNoteOptional,
                  alignLabelWithHint: true,
                ),
              ),
              FilledButton(
                onPressed: _ids.isEmpty
                    ? null
                    : () =>
                          Navigator.of(context)
                              .pop(_ReferDraft(_ids, _note.text.trim())),
                child: Text(l.referralSend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.label,
    required this.confirm,
  });
  final String title;
  final String label;
  final String confirm;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _note,
        maxLines: 3,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
