import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart' show toPersianDigits;
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/polls/models.dart';
import 'package:letter_signing/polls/poll_ui.dart';
import 'package:letter_signing/polls/polls_env.dart';

/// Create a poll or quiz for [targetSubjectId]: questions, options, multi-answer, correct
/// answers and points (quiz), anonymity, and templates (use / save).
class PollCreateScreen extends StatefulWidget {
  const PollCreateScreen({
    super.key,
    required this.env,
    required this.targetSubjectId,
  });
  final PollsEnv env;
  final String targetSubjectId;

  @override
  State<PollCreateScreen> createState() => _PollCreateState();
}

class _PollCreateState extends State<PollCreateScreen> {
  final _title = TextEditingController();
  String _kind = 'poll';
  String _anonymity = 'public';
  List<QuestionDraft> _questions = const [QuestionDraft()];
  // Bumped when a template replaces the questions so the text fields rebuild.
  int _generation = 0;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _set(int i, QuestionDraft q) => setState(
    () =>
        _questions = [for (final (j, e) in _questions.indexed) j == i ? q : e],
  );

  DraftProblem? get _problem => validateDraft(
    title: _title.text,
    quiz: _kind == 'quiz',
    questions: _questions,
  );

  String _problemText(AppLocalizations l, DraftProblem p) => switch (p) {
    DraftProblem.noTitle => l.pollNoTitle,
    DraftProblem.noQuestionText => l.pollNoQuestion,
    DraftProblem.tooFewOptions => l.pollTooFewOptions,
    DraftProblem.noCorrect => l.pollNoCorrect,
  };

  Future<void> _create() async {
    final l = AppLocalizations.of(context);
    final problem = _problem;
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_problemText(l, problem))));
      return;
    }
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await widget.env.api.create(
        targetSubjectId: widget.targetSubjectId,
        title: _title.text,
        kind: _kind,
        anonymity: _anonymity,
        questions: _questions,
      );
      nav.pop(true);
    } on Object catch (e) {
      if (mounted) pollError(context, e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useTemplate() async {
    final l = AppLocalizations.of(context);
    try {
      final all = await widget.env.api.templates();
      if (!mounted) return;
      final picked = await showModalBottomSheet<PollTemplate>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: all.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.pollNoTemplates),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in all)
                      ListTile(
                        title: Text(t.name),
                        subtitle: Text(pollKindLabel(l, t.kind)),
                        onTap: () => Navigator.pop(ctx, t),
                      ),
                  ],
                ),
        ),
      );
      if (picked == null) return;
      setState(() {
        _title.text = picked.title;
        _kind = picked.kind;
        _anonymity = picked.anonymity;
        _questions = picked.questions.isEmpty
            ? const [QuestionDraft()]
            : picked.questions;
        _generation++;
      });
    } on Object catch (e) {
      if (mounted) pollError(context, e);
    }
  }

  Future<void> _saveTemplate() async {
    final l = AppLocalizations.of(context);
    final name = TextEditingController(text: _title.text);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.pollSaveTemplate),
        content: TextField(
          controller: name,
          decoration: InputDecoration(labelText: l.pollTemplateName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    final text = name.text;
    name.dispose();
    if (ok != true || text.trim().isEmpty) return;
    try {
      await widget.env.api.saveTemplate(
        name: text,
        title: _title.text,
        kind: _kind,
        anonymity: _anonymity,
        questions: _questions,
      );
      messenger.showSnackBar(SnackBar(content: Text(l.pollTemplateSaved)));
    } on Object catch (e) {
      if (mounted) pollError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final quiz = _kind == 'quiz';
    return Scaffold(
      appBar: AppBar(
        title: Text(l.pollNew),
        actions: [
          IconButton(
            key: const ValueKey('poll-templates'),
            tooltip: l.pollTemplates,
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () => unawaited(_useTemplate()),
          ),
          IconButton(
            key: const ValueKey('poll-save-template'),
            tooltip: l.pollSaveTemplate,
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () => unawaited(_saveTemplate()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: ValueKey('poll-title-$_generation'),
            controller: _title,
            maxLength: 200,
            decoration: InputDecoration(labelText: l.pollTitleField),
          ),
          SegmentedButton<String>(
            segments: [
              for (final k in pollKinds)
                ButtonSegment(value: k, label: Text(pollKindLabel(l, k))),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('poll-anon-$_anonymity'),
            initialValue: _anonymity,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.pollAnonymity),
            items: [
              for (final a in pollAnonymities)
                DropdownMenuItem(
                  value: a,
                  child: Text(
                    pollAnonymityLabel(l, a),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _anonymity = v ?? _anonymity),
          ),
          for (final (i, q) in _questions.indexed)
            _QuestionEditor(
              key: ValueKey('q-$_generation-$i'),
              index: i,
              draft: q,
              quiz: quiz,
              onChanged: (n) => _set(i, n),
              onRemove: _questions.length < 2
                  ? null
                  : () => setState(
                      () => _questions = [
                        for (final (j, e) in _questions.indexed)
                          if (j != i) e,
                      ],
                    ),
            ),
          TextButton.icon(
            key: const ValueKey('poll-add-question'),
            onPressed: () => setState(
              () => _questions = [..._questions, const QuestionDraft()],
            ),
            icon: const Icon(Icons.add),
            label: Text(l.pollAddQuestion),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey('poll-create'),
            onPressed: _busy ? null : () => unawaited(_create()),
            child: Text(l.pollCreate),
          ),
        ],
      ),
    );
  }
}

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({
    super.key,
    required this.index,
    required this.draft,
    required this.quiz,
    required this.onChanged,
    required this.onRemove,
  });
  final int index;
  final QuestionDraft draft;
  final bool quiz;
  final ValueChanged<QuestionDraft> onChanged;
  final VoidCallback? onRemove;

  void _options(List<String> options, Set<int> correct) =>
      onChanged(draft.copyWith(options: options, correct: correct));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final opts = draft.options;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.pollQuestionN(toPersianDigits(index + 1)),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: l.pollRemoveQuestion,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onRemove,
                  ),
              ],
            ),
            TextFormField(
              key: ValueKey('q$index-text'),
              initialValue: draft.text,
              maxLength: 500,
              decoration: InputDecoration(labelText: l.pollQuestionText),
              onChanged: (v) => onChanged(draft.copyWith(text: v)),
            ),
            if (quiz) Text(l.pollCorrectHint),
            for (final (j, o) in opts.indexed)
              Row(
                children: [
                  if (quiz)
                    Checkbox(
                      key: ValueKey('q$index-correct-$j'),
                      value: draft.correct.contains(j),
                      onChanged: (on) => onChanged(
                        draft.copyWith(
                          correct: {
                            for (final c in draft.correct)
                              if (c != j) c,
                            if (on == true) j,
                          },
                        ),
                      ),
                    ),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('q$index-opt-$j-${opts.length}'),
                      initialValue: o,
                      maxLength: 300,
                      decoration: InputDecoration(
                        labelText:
                            '${l.pollOptionHint} ${toPersianDigits(j + 1)}',
                        counterText: '',
                      ),
                      onChanged: (v) => onChanged(
                        draft.copyWith(
                          options: [
                            for (final (k, e) in opts.indexed) k == j ? v : e,
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (opts.length > 2)
                    IconButton(
                      tooltip: l.pollRemoveOption,
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _options(
                        [
                          for (final (k, e) in opts.indexed)
                            if (k != j) e,
                        ],
                        {
                          for (final c in draft.correct)
                            if (c != j) c > j ? c - 1 : c,
                        },
                      ),
                    ),
                ],
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: ValueKey('q$index-add-option'),
                onPressed: opts.length >= 20
                    ? null
                    : () => _options([...opts, ''], draft.correct),
                icon: const Icon(Icons.add),
                label: Text(l.pollAddOption),
              ),
            ),
            SwitchListTile(
              key: ValueKey('q$index-multiple'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.pollMultiple),
              value: draft.multiple,
              onChanged: (v) => onChanged(draft.copyWith(multiple: v)),
            ),
            if (quiz)
              Row(
                children: [
                  Text(l.pollPoints),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: draft.points > 1
                        ? () => onChanged(
                            draft.copyWith(points: draft.points - 1),
                          )
                        : null,
                  ),
                  Text(toPersianDigits(draft.points)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: draft.points < 100
                        ? () => onChanged(
                            draft.copyWith(points: draft.points + 1),
                          )
                        : null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
