import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_detail_screen.dart';
import 'package:letter_signing/meetings/meeting_detail_screen.dart';
import 'package:letter_signing/notes/note_editor_screen.dart';
import 'package:letter_signing/polls/poll_screen.dart';
import 'package:letter_signing/projects/project_detail_screen.dart';
import 'package:letter_signing/tasks/task_detail_screen.dart';
import 'package:letter_signing/workspace/coming_soon_screen.dart';
import 'package:letter_signing/workspace/open_target.dart';
import 'package:letter_signing/workspace/workspace_env.dart';

/// Opens the screen that shows [target]. Modules registered in `env.openers` (chat, CRM ...)
/// win; modules without a screen yet get the "coming soon" page.
Future<void> openTarget(
  BuildContext context,
  WorkspaceEnv env,
  OpenTarget target,
) async {
  final custom = env.openers[target.module];
  if (custom != null && await custom(context, target)) return;
  if (!context.mounted) return;
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final failed = AppLocalizations.of(context).openFailed;
  try {
    final page = await _page(env, target);
    if (page == null) return;
    unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => page)));
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }
}

Future<Widget?> _page(WorkspaceEnv env, OpenTarget t) async =>
    switch (t.module) {
      'tasks' => TaskDetailScreen(env: env.tasks, taskId: t.id),
      'letters' => LetterDetailScreen(env: env.letters, letterId: t.id),
      'meetings' => MeetingDetailScreen(env: env.meetings, meetingId: t.id),
      'projects' => ProjectDetailScreen(
        env: env.projects,
        projectId: await _projectId(env, t),
      ),
      'notes' => NoteEditorScreen(
        env: env.notes,
        note: await env.notes.api.get(t.id),
      ),
      'polls' => PollScreen(env: env.polls, pollId: t.id),
      _ => const _Soon(),
    };

/// A pin only knows the subject id; projects are opened by their own id.
Future<String> _projectId(WorkspaceEnv env, OpenTarget t) async {
  if (t.kind != 'subject') return t.id;
  final all = await env.projects.api.list();
  return all.firstWhere((p) => p.subjectId == t.subjectId).id;
}

class _Soon extends StatelessWidget {
  const _Soon();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).comingSoonTitle)),
    body: const ComingSoonScreen(icon: Icons.construction_outlined),
  );
}
