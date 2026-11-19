import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Persian names and colours for task enums, and the due-date text.
String statusLabel(AppLocalizations l, String status) => switch (status) {
  TaskStatus.open => l.taskStatusOpen,
  TaskStatus.awaitingApproval => l.taskStatusAwaiting,
  TaskStatus.done => l.taskStatusDone,
  TaskStatus.cancelled => l.taskStatusCancelled,
  _ => status,
};

Tone statusTone(String status) => switch (status) {
  TaskStatus.open => Tone.info,
  TaskStatus.awaitingApproval => Tone.warn,
  TaskStatus.done => Tone.ok,
  _ => Tone.neutral,
};

String priorityLabel(AppLocalizations l, String priority) => switch (priority) {
  TaskPriority.low => l.taskPriorityLow,
  TaskPriority.normal => l.taskPriorityNormal,
  TaskPriority.high => l.taskPriorityHigh,
  TaskPriority.urgent => l.taskPriorityUrgent,
  _ => priority,
};

Tone priorityTone(String priority) => switch (priority) {
  TaskPriority.urgent => Tone.error,
  TaskPriority.high => Tone.warn,
  _ => Tone.neutral,
};

/// A due date in Jalali; all-day dates carry no time.
String formatDue(DateTime due, {required bool allDay}) =>
    allDay ? formatJalaliDate(due) : formatJalaliDateTime(due);
