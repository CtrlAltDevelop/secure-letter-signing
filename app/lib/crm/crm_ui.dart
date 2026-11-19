import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';

String customerKindLabel(AppLocalizations l, String kind) => switch (kind) {
  CustomerKind.company => l.crmKindCompany,
  _ => l.crmKindPerson,
};

String customerStatusLabel(AppLocalizations l, String status) =>
    switch (status) {
      CustomerStatus.inactive => l.crmStatusInactive,
      CustomerStatus.archived => l.crmStatusArchived,
      _ => l.crmStatusActive,
    };

Tone customerStatusTone(String status) => switch (status) {
  CustomerStatus.inactive => Tone.warn,
  CustomerStatus.archived => Tone.neutral,
  _ => Tone.ok,
};

String memberRoleLabel(AppLocalizations l, String role) => switch (role) {
  MemberRole.manager => l.crmRoleManager,
  MemberRole.viewer => l.crmRoleViewer,
  _ => l.crmRoleMember,
};

String eventKindLabel(AppLocalizations l, String kind) => switch (kind) {
  EventKind.call => l.crmEventCall,
  EventKind.meeting => l.crmEventMeeting,
  EventKind.finance => l.crmEventFinance,
  EventKind.lead => l.crmEventLead,
  EventKind.system => l.crmEventSystem,
  EventKind.task => l.crmEventTask,
  EventKind.letter => l.crmEventLetter,
  _ => l.crmEventNote,
};

IconData eventKindIcon(String kind) => switch (kind) {
  EventKind.call => Icons.call_outlined,
  EventKind.meeting => Icons.groups_outlined,
  EventKind.finance => Icons.account_balance_wallet_outlined,
  EventKind.lead => Icons.trending_up,
  EventKind.system => Icons.settings_outlined,
  EventKind.task => Icons.task_alt_outlined,
  EventKind.letter => Icons.mail_outline,
  _ => Icons.sticky_note_2_outlined,
};

/// Roles allowed to write on a customer file.
bool canWrite(String role) =>
    role == MemberRole.manager || role == MemberRole.member;
