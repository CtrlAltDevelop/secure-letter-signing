import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show PersonAvatar;
import 'package:letter_signing/letters/letter_detail_parts.dart'
    show decisionLabel, methodLabel;
import 'package:letter_signing/meetings/meeting_ui.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// The header card: status, kind, time, place and who created the meeting.
class MeetingInfoCard extends StatelessWidget {
  const MeetingInfoCard({super.key, required this.meeting});
  final MeetingOut meeting;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 13);
    final b = meeting.brief;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MeetingStatusPill(b.status),
              StatusPill(
                meetingKindLabel(l, b.kind),
                tone: b.isOrganizational ? Tone.info : Tone.neutral,
              ),
              if (b.revision > 1)
                StatusPill(
                  l.meetingRevision(toPersianDigits(b.revision)),
                  tone: Tone.warn,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(b.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _line(
            Icons.event_outlined,
            meetingWhen(b.startsAt, l.meetingNoDate),
            muted,
          ),
          if (b.endsAt != null)
            _line(
              Icons.event_available_outlined,
              meetingWhen(b.endsAt, ''),
              muted,
            ),
          if (b.location.isNotEmpty)
            _line(Icons.place_outlined, b.location, muted),
          _line(
            Icons.person_outline,
            l.meetingCreatedBy(meeting.creator.displayName),
            muted,
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text, TextStyle style) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: style.color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: style)),
      ],
    ),
  );
}

/// Attendees with their roles; the chair and secretary mark attendance while the meeting runs.
class AttendeesSection extends StatelessWidget {
  const AttendeesSection({
    super.key,
    required this.meeting,
    required this.onMark,
  });
  final MeetingOut meeting;
  final Future<void> Function(Attendee a, String attendance) onMark;

  bool get _canMark =>
      meeting.can.run &&
      (meeting.status == MeetingStatus.scheduled ||
          meeting.status == MeetingStatus.held);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          l.meetingAttendees,
          subtitle: _canMark ? l.meetingAttendanceHint : null,
        ),
        AppCard(
          child: meeting.attendees.isEmpty
              ? Text(l.meetingNoAttendees)
              : Column(
                  children: [
                    for (final a in meeting.attendees) _row(context, a, l),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Attendee a, AppLocalizations l) {
    final pill = StatusPill(
      attendanceLabel(l, a.attendance),
      tone: attendanceTone(a.attendance),
    );
    return ListTile(
      key: ValueKey('attendee-${a.id}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: PersonAvatar(a.displayName, size: 32),
      title: Text(a.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        a.isGuest
            ? '${attendeeRoleLabel(l, a.role)}  -  ${l.meetingExternalGuest}'
            : attendeeRoleLabel(l, a.role),
      ),
      trailing: _canMark
          ? PopupMenuButton<String>(
              tooltip: l.meetingMarkAttendance,
              onSelected: (v) => unawaited(onMark(a, v)),
              itemBuilder: (_) => [
                for (final v in Attendance.all)
                  PopupMenuItem(value: v, child: Text(attendanceLabel(l, v))),
              ],
              child: pill,
            )
          : pill,
    );
  }
}

/// The minutes text with an edit button for the people who may record.
class MinutesSection extends StatelessWidget {
  const MinutesSection({
    super.key,
    required this.meeting,
    required this.onEdit,
  });
  final MeetingOut meeting;
  final VoidCallback onEdit;

  bool get _canEdit =>
      meeting.can.record &&
      meeting.status != MeetingStatus.closed &&
      meeting.status != MeetingStatus.cancelled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          l.meetingMinutes,
          trailing: _canEdit
              ? TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l.meetingEditMinutes),
                )
              : null,
        ),
        AppCard(
          child: meeting.description.isEmpty
              ? Text(l.meetingNoMinutes)
              : SelectableText(meeting.description),
        ),
      ],
    );
  }
}

/// The sealed signatures of the minutes: decision, method, stale and validity flags.
class SignaturesSection extends StatelessWidget {
  const SignaturesSection({super.key, required this.meeting, this.onSign});
  final MeetingOut meeting;

  /// Null when the user cannot sign now.
  final VoidCallback? onSign;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          l.meetingSignatures,
          subtitle: meeting.allSigned ? l.meetingAllSigned : null,
        ),
        AppCard(
          child: meeting.signatures.isEmpty
              ? Text(l.meetingNoSignatures)
              : Column(
                  children: [
                    for (final s in meeting.signatures) _row(context, s, l),
                  ],
                ),
        ),
        if (onSign != null) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onSign,
            icon: const Icon(Icons.draw_outlined),
            label: Text(l.meetingSign),
          ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, MeetingSignature s, AppLocalizations l) {
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12.5,
    );
    final approved = s.decision == 'approved';
    return Padding(
      key: ValueKey('signature-${s.id}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PersonAvatar(
                s.user.displayName,
                size: 30,
                color: approved ? Tokens.ok : Tokens.error,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(s.user.displayName)),
              StatusPill(
                decisionLabel(l, s.decision),
                tone: approved ? Tone.ok : Tone.error,
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(methodLabel(l, s.method), style: muted),
              if (s.createdAt != null)
                Text(
                  '${formatJalaliDate(s.createdAt!)} ${formatJalaliTime(s.createdAt!)}',
                  style: muted,
                ),
              if (s.stale) StatusPill(l.meetingSignatureStale, tone: Tone.warn),
              StatusPill(
                s.valid ? l.certValid : l.certInvalid,
                tone: s.valid ? Tone.ok : Tone.error,
              ),
            ],
          ),
          if (s.note.isNotEmpty) Text('"${s.note}"'),
        ],
      ),
    );
  }
}
