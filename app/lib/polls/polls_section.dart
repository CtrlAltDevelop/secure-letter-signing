import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart' show toPersianDigits;
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/polls/models.dart';
import 'package:letter_signing/polls/poll_create_screen.dart';
import 'package:letter_signing/polls/poll_screen.dart';
import 'package:letter_signing/polls/polls_env.dart';

/// The polls of one subject (a chat conversation, a project, a customer file) with a create
/// button. Embed it in a tab or push [PollsScreen].
class PollsSection extends StatefulWidget {
  const PollsSection({
    super.key,
    required this.env,
    required this.targetSubjectId,
  });
  final PollsEnv env;
  final String targetSubjectId;

  @override
  State<PollsSection> createState() => _PollsSectionState();
}

class _PollsSectionState extends State<PollsSection> {
  List<Poll>? _polls;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final rows = await widget.env.api.list(
        targetSubject: widget.targetSubjectId,
      );
      if (mounted) setState(() => _polls = rows);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final polls = _polls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('poll-new'),
            onPressed: () => unawaited(
              _open(
                PollCreateScreen(
                  env: widget.env,
                  targetSubjectId: widget.targetSubjectId,
                ),
              ),
            ),
            icon: const Icon(Icons.add_chart),
            label: Text(l.pollNew),
          ),
        ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.pollLoadFailed),
          )
        else if (polls == null)
          const Center(child: CircularProgressIndicator())
        else if (polls.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text(l.pollsEmpty))
        else
          for (final p in polls)
            ListTile(
              key: ValueKey('poll-${p.id}'),
              leading: Icon(
                p.isQuiz ? Icons.quiz_outlined : Icons.poll_outlined,
              ),
              title: Text(p.title),
              subtitle: Text(
                '${p.closed ? l.pollClosedBadge : l.pollOpenBadge}  -  '
                '${l.pollParticipants(toPersianDigits(p.participants))}',
              ),
              trailing: p.iSubmitted ? const Icon(Icons.check_circle) : null,
              onTap: () =>
                  unawaited(_open(PollScreen(env: widget.env, pollId: p.id))),
            ),
      ],
    );
  }
}

/// A full page around [PollsSection] (menu entries open this).
class PollsScreen extends StatelessWidget {
  const PollsScreen({
    super.key,
    required this.env,
    required this.targetSubjectId,
  });
  final PollsEnv env;
  final String targetSubjectId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).pollsTitle)),
    body: SingleChildScrollView(
      child: PollsSection(env: env, targetSubjectId: targetSubjectId),
    ),
  );
}
