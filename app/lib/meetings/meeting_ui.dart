import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/theme/widgets.dart';

String meetingStatusLabel(AppLocalizations l, String status) =>
    switch (status) {
      MeetingStatus.draft => l.meetingStatusDraft,
      MeetingStatus.scheduled => l.meetingStatusScheduled,
      MeetingStatus.held => l.meetingStatusHeld,
      MeetingStatus.closed => l.meetingStatusClosed,
      MeetingStatus.cancelled => l.meetingStatusCancelled,
      _ => status,
    };

Tone meetingStatusTone(String status) => switch (status) {
  MeetingStatus.scheduled => Tone.info,
  MeetingStatus.held => Tone.warn,
  MeetingStatus.closed => Tone.ok,
  MeetingStatus.cancelled => Tone.error,
  _ => Tone.neutral,
};

String meetingKindLabel(AppLocalizations l, String kind) =>
    kind == MeetingKind.organizational
    ? l.meetingKindOrganizational
    : l.meetingKindSimple;

String attendeeRoleLabel(AppLocalizations l, String role) => switch (role) {
  AttendeeRole.chair => l.meetingRoleChair,
  AttendeeRole.secretary => l.meetingRoleSecretary,
  AttendeeRole.guest => l.meetingRoleGuest,
  _ => l.meetingRoleMember,
};

String attendanceLabel(AppLocalizations l, String attendance) =>
    switch (attendance) {
      Attendance.present => l.meetingAttendancePresent,
      Attendance.absent => l.meetingAttendanceAbsent,
      Attendance.excused => l.meetingAttendanceExcused,
      _ => l.meetingAttendanceUnknown,
    };

Tone attendanceTone(String attendance) => switch (attendance) {
  Attendance.present => Tone.ok,
  Attendance.absent => Tone.error,
  Attendance.excused => Tone.warn,
  _ => Tone.neutral,
};

/// `شنبه ۱ فروردین ۱۴۰۵ ۱۴:۰۵`, or the fallback when there is no date.
String meetingWhen(DateTime? when, String fallback) => when == null
    ? fallback
    : '${formatJalaliLong(when)} ${formatJalaliTime(when)}';

/// Status pill of a meeting.
class MeetingStatusPill extends StatelessWidget {
  const MeetingStatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) => StatusPill(
    meetingStatusLabel(AppLocalizations.of(context), status),
    tone: meetingStatusTone(status),
  );
}
