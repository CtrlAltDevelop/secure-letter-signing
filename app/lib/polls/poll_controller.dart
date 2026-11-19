import 'package:flutter/foundation.dart';

import 'package:letter_signing/polls/models.dart';
import 'package:letter_signing/polls/polls_api.dart';

/// One poll: the choices being edited, submit, close and results.
class PollController extends ChangeNotifier {
  PollController({required this.api, required this.pollId});
  final PollsApi api;
  final String pollId;

  Poll? poll;
  PollResults? results;
  Object? error;
  bool busy = false;

  /// question id -> chosen option ids (starts from my saved answers).
  Map<int, Set<int>> choices = {};

  Future<void> load() async {
    try {
      _adopt(await api.get(pollId));
      error = null;
      await loadResults();
    } on Object catch (e) {
      error = e;
    }
    notifyListeners();
  }

  void _adopt(Poll p) {
    poll = p;
    choices = {for (final e in p.myAnswers.entries) e.key: e.value.toSet()};
  }

  /// Results stay null when the server refuses them (not voted yet).
  Future<void> loadResults() async {
    final p = poll;
    if (p == null || !p.can.results) {
      results = null;
      return;
    }
    try {
      results = await api.results(pollId);
    } on Object {
      results = null;
    }
  }

  void choose(PollQuestion q, int optionId, {required bool on}) {
    final next = {...?choices[q.id]};
    if (!q.multiple) next.clear();
    on ? next.add(optionId) : next.remove(optionId);
    choices = {...choices, q.id: next};
    notifyListeners();
  }

  /// Every question needs at least one option.
  bool get complete {
    final p = poll;
    return p != null &&
        p.questions.every((q) => (choices[q.id] ?? const {}).isNotEmpty);
  }

  Future<bool> submit() => _act(() => api.submit(pollId, choices));
  Future<bool> close() => _act(() => api.close(pollId));

  Future<bool> _act(Future<Poll> Function() run) async {
    busy = true;
    notifyListeners();
    try {
      _adopt(await run());
      error = null;
      await loadResults();
      busy = false;
      notifyListeners();
      return true;
    } on Object catch (e) {
      error = e;
      busy = false;
      notifyListeners();
      return false;
    }
  }
}
