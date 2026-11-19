import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart' show toPersianDigits;
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/polls/models.dart';
import 'package:letter_signing/polls/poll_controller.dart';
import 'package:letter_signing/polls/poll_results_view.dart';
import 'package:letter_signing/polls/poll_ui.dart';
import 'package:letter_signing/polls/polls_env.dart';

/// Answer a poll (or change the answer while it is open), see its results, end it (manager).
class PollScreen extends StatefulWidget {
  const PollScreen({super.key, required this.env, required this.pollId});
  final PollsEnv env;
  final String pollId;

  @override
  State<PollScreen> createState() => _PollScreenState();
}

class _PollScreenState extends State<PollScreen> {
  late final PollController _c = PollController(
    api: widget.env.api,
    pollId: widget.pollId,
  )..addListener(_changed);

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    unawaited(_c.load());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (await _c.submit()) {
      messenger.showSnackBar(SnackBar(content: Text(l.pollSubmitted)));
    } else if (mounted) {
      pollError(context, _c.error!);
    }
  }

  Future<void> _close() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.pollClose),
        content: Text(l.pollCloseConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('poll-close-yes'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!await _c.close() && mounted) pollError(context, _c.error!);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = _c.poll;
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.title ?? '', overflow: TextOverflow.ellipsis),
        actions: [
          if (p != null && p.can.close)
            IconButton(
              key: const ValueKey('poll-close'),
              tooltip: l.pollClose,
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _c.busy ? null : () => unawaited(_close()),
            ),
        ],
      ),
      body: p == null
          ? Center(
              child: _c.error == null
                  ? const CircularProgressIndicator()
                  : Text(l.pollLoadFailed),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${pollKindLabel(l, p.kind)}  -  '
                  '${p.closed ? l.pollClosedBadge : l.pollOpenBadge}  -  '
                  '${l.pollParticipants(toPersianDigits(p.participants))}',
                ),
                Text(pollAnonymityLabel(l, p.anonymity)),
                if (p.can.submit) ..._form(l, p),
                if (!p.can.submit && _c.results == null && !p.can.results)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(l.pollVoteFirst),
                  ),
                if (_c.results != null) ...[
                  const Divider(height: 32),
                  Text(
                    l.pollResults,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  PollResultsView(
                    poll: p,
                    results: _c.results!,
                    env: widget.env,
                  ),
                ],
              ],
            ),
    );
  }

  List<Widget> _form(AppLocalizations l, Poll p) => [
    for (final (i, q) in p.questions.indexed)
      Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${toPersianDigits(i + 1)}. ${q.text}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final o in q.options)
                _choice(q, o, _c.choices[q.id]?.contains(o.id) ?? false),
            ],
          ),
        ),
      ),
    const SizedBox(height: 12),
    FilledButton(
      key: const ValueKey('poll-submit'),
      onPressed: _c.complete && !_c.busy ? () => unawaited(_submit()) : null,
      child: Text(p.iSubmitted ? l.pollChangeAnswer : l.pollSubmit),
    ),
  ];

  Widget _choice(PollQuestion q, PollOption o, bool on) => q.multiple
      ? CheckboxListTile(
          key: ValueKey('opt-${o.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(o.text),
          value: on,
          onChanged: (v) => _c.choose(q, o.id, on: v == true),
        )
      : ListTile(
          key: ValueKey('opt-${o.id}'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          ),
          title: Text(o.text),
          onTap: () => _c.choose(q, o.id, on: true),
        );
}
