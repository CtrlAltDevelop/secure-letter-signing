import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart' show toPersianDigits;
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/polls/models.dart';
import 'package:letter_signing/polls/poll_print.dart';
import 'package:letter_signing/polls/polls_env.dart';
import 'package:letter_signing/workspace/models.dart';

/// Count / percent bars per option, voter names only when the server sent them, quiz scores,
/// and (for the manager who got scores) a print button.
class PollResultsView extends StatelessWidget {
  const PollResultsView({
    super.key,
    required this.poll,
    required this.results,
    required this.env,
  });
  final Poll poll;
  final PollResults results;
  final PollsEnv env;

  Future<void> _print(BuildContext context) async {
    var head = const Letterhead();
    try {
      head = Letterhead.fromJson(
        asMap(await env.api.workspace.call('GET', '/me/letterhead')),
      );
    } on Object {
      // Printing works without a letterhead.
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            PollPrintScreen(poll: poll, results: results, head: head),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scores = results.scores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (results.myScore != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l.pollMyScore(
                toPersianDigits(results.myScore!),
                toPersianDigits(results.maxScore ?? 0),
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        for (final q in results.questions) _question(context, l, q),
        if (scores != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.pollScores,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                key: const ValueKey('poll-print'),
                onPressed: () => unawaited(_print(context)),
                icon: const Icon(Icons.print_outlined),
                label: Text(l.pollPrint),
              ),
            ],
          ),
          for (final s in scores)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(s.user.displayName),
              trailing: Text(
                '${toPersianDigits(s.score)} / ${toPersianDigits(s.maxScore)}',
              ),
            ),
        ],
      ],
    );
  }

  Widget _question(BuildContext context, AppLocalizations l, QuestionResult q) {
    final total = q.total;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.text, style: Theme.of(context).textTheme.titleSmall),
            for (final o in q.options)
              _option(context, l, o, total, q.correct?.contains(o.id) ?? false),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context,
    AppLocalizations l,
    OptionResult o,
    int total,
    bool correct,
  ) {
    final share = total == 0 ? 0.0 : o.count / total;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (correct)
                Tooltip(
                  message: l.pollCorrect,
                  child: const Icon(Icons.check_circle, size: 16),
                ),
              Expanded(child: Text(o.text)),
              Text(
                '${toPersianDigits(o.count)}  (${toPersianDigits((share * 100).round())}٪)',
              ),
            ],
          ),
          LinearProgressIndicator(value: share, minHeight: 6),
          if (o.voters != null && o.voters!.isNotEmpty)
            Text(
              o.voters!.map((v) => v.displayName).join('، '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
