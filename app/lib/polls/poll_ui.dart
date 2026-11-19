import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome, outcomeOf;

String pollKindLabel(AppLocalizations l, String kind) =>
    kind == 'quiz' ? l.pollKindQuiz : l.pollKindPoll;

String pollAnonymityLabel(AppLocalizations l, String a) => switch (a) {
  'anonymous_to_users' => l.pollAnonUsers,
  'anonymous_to_all' => l.pollAnonAll,
  _ => l.pollAnonPublic,
};

/// A server failure as a SnackBar in Persian.
void pollError(BuildContext context, Object error) {
  final l = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        outcomeOf(error) == ActionOutcome.forbidden
            ? l.pollForbidden
            : l.pollActionFailed,
      ),
    ),
  );
}
