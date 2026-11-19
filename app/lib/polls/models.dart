import 'package:flutter/foundation.dart';

import 'package:letter_signing/workspace/models.dart';

const pollKinds = ['poll', 'quiz'];
const pollAnonymities = ['public', 'anonymous_to_users', 'anonymous_to_all'];

@immutable
class PollOption {
  const PollOption({required this.id, required this.text});
  final int id;
  final String text;
  factory PollOption.fromJson(Map<String, dynamic> j) =>
      PollOption(id: asInt(j['id']) ?? 0, text: asString(j['text']));
}

@immutable
class PollQuestion {
  const PollQuestion({
    required this.id,
    required this.text,
    required this.multiple,
    required this.points,
    required this.options,
    this.correct,
  });
  final int id;
  final String text;
  final bool multiple;
  final int points;
  final List<PollOption> options;

  /// Quiz only: null while the server hides the correct answers.
  final List<int>? correct;

  factory PollQuestion.fromJson(Map<String, dynamic> j) => PollQuestion(
    id: asInt(j['id']) ?? 0,
    text: asString(j['text']),
    multiple: j['multiple'] == true,
    points: asInt(j['points']) ?? 1,
    options: [for (final o in asMapList(j['options'])) PollOption.fromJson(o)],
    correct: j['correct_option_ids'] is List
        ? asIntList(j['correct_option_ids'])
        : null,
  );
}

@immutable
class PollCan {
  const PollCan({
    this.submit = false,
    this.close = false,
    this.results = false,
    this.seeVoters = false,
  });
  final bool submit;
  final bool close;
  final bool results;
  final bool seeVoters;
  factory PollCan.fromJson(Map<String, dynamic> j) => PollCan(
    submit: j['submit'] == true,
    close: j['close'] == true,
    results: j['results'] == true,
    seeVoters: j['see_voters'] == true,
  );
}

/// `PollBrief`, plus questions / my answers / permissions for `PollOut`.
@immutable
class Poll {
  const Poll({
    required this.id,
    required this.targetSubjectId,
    required this.title,
    required this.kind,
    required this.anonymity,
    required this.closed,
    required this.participants,
    required this.questionCount,
    required this.iSubmitted,
    this.creator,
    this.questions = const [],
    this.myAnswers = const {},
    this.can = const PollCan(),
  });
  final String id;
  final String targetSubjectId;
  final String title;
  final String kind;
  final String anonymity;
  final bool closed;
  final int participants;
  final int questionCount;
  final bool iSubmitted;
  final UserRef? creator;
  final List<PollQuestion> questions;
  final Map<int, List<int>> myAnswers;
  final PollCan can;

  bool get isQuiz => kind == 'quiz';

  factory Poll.fromJson(Map<String, dynamic> j) {
    final mine = asMap(j['my_answers']);
    return Poll(
      id: asString(j['id']),
      targetSubjectId: asString(j['target_subject_id']),
      title: asString(j['title']),
      kind: asString(j['kind'], 'poll'),
      anonymity: asString(j['anonymity'], 'public'),
      closed: j['status'] == 'closed',
      participants: asInt(j['participants']) ?? 0,
      questionCount: asInt(j['question_count']) ?? 0,
      iSubmitted: j['i_submitted'] == true,
      creator: UserRef.maybe(j['creator']),
      questions: [
        for (final q in asMapList(j['questions'])) PollQuestion.fromJson(q),
      ],
      myAnswers: {
        for (final e in mine.entries) int.parse(e.key): asIntList(e.value),
      },
      can: PollCan.fromJson(asMap(j['can'])),
    );
  }
}

@immutable
class OptionResult {
  const OptionResult({
    required this.id,
    required this.text,
    required this.count,
    this.voters,
  });
  final int id;
  final String text;
  final int count;

  /// Null when the server hides the voters from this caller.
  final List<UserRef>? voters;
  factory OptionResult.fromJson(Map<String, dynamic> j) => OptionResult(
    id: asInt(j['id']) ?? 0,
    text: asString(j['text']),
    count: asInt(j['count']) ?? 0,
    voters: j['voters'] is List
        ? [for (final v in asMapList(j['voters'])) UserRef.fromJson(v)]
        : null,
  );
}

@immutable
class QuestionResult {
  const QuestionResult({
    required this.text,
    required this.options,
    this.correct,
  });
  final String text;
  final List<OptionResult> options;
  final List<int>? correct;

  int get total => options.fold(0, (a, o) => a + o.count);

  factory QuestionResult.fromJson(Map<String, dynamic> j) => QuestionResult(
    text: asString(j['text']),
    options: [
      for (final o in asMapList(j['options'])) OptionResult.fromJson(o),
    ],
    correct: j['correct_option_ids'] is List
        ? asIntList(j['correct_option_ids'])
        : null,
  );
}

@immutable
class PollScore {
  const PollScore({
    required this.user,
    required this.score,
    required this.maxScore,
  });
  final UserRef user;
  final int score;
  final int maxScore;
}

@immutable
class PollResults {
  const PollResults({
    required this.kind,
    required this.closed,
    required this.participants,
    required this.questions,
    this.scores,
    this.myScore,
    this.maxScore,
  });
  final String kind;
  final bool closed;
  final int participants;
  final List<QuestionResult> questions;
  final List<PollScore>? scores;
  final int? myScore;
  final int? maxScore;

  factory PollResults.fromJson(Map<String, dynamic> j) => PollResults(
    kind: asString(j['kind'], 'poll'),
    closed: j['status'] == 'closed',
    participants: asInt(j['participants']) ?? 0,
    questions: [
      for (final q in asMapList(j['questions'])) QuestionResult.fromJson(q),
    ],
    scores: j['scores'] is List
        ? [
            for (final s in asMapList(j['scores']))
              PollScore(
                user: UserRef.fromJson(asMap(s['user'])),
                score: asInt(s['score']) ?? 0,
                maxScore: asInt(s['max_score']) ?? 0,
              ),
          ]
        : null,
    myScore: asInt(j['my_score']),
    maxScore: asInt(j['max_score']),
  );
}

/// A question being written: [correct] holds indexes into [options].
@immutable
class QuestionDraft {
  const QuestionDraft({
    this.text = '',
    this.multiple = false,
    this.options = const ['', ''],
    this.correct = const {},
    this.points = 1,
  });
  final String text;
  final bool multiple;
  final List<String> options;
  final Set<int> correct;
  final int points;

  QuestionDraft copyWith({
    String? text,
    bool? multiple,
    List<String>? options,
    Set<int>? correct,
    int? points,
  }) => QuestionDraft(
    text: text ?? this.text,
    multiple: multiple ?? this.multiple,
    options: options ?? this.options,
    correct: correct ?? this.correct,
    points: points ?? this.points,
  );

  Map<String, dynamic> toJson() => {
    'text': text.trim(),
    'multiple': multiple,
    'options': [for (final o in options) o.trim()],
    'correct': (correct.toList()..sort()),
    'points': points,
  };

  factory QuestionDraft.fromJson(Map<String, dynamic> j) => QuestionDraft(
    text: asString(j['text']),
    multiple: j['multiple'] == true,
    options: [
      if (j['options'] is List)
        for (final o in j['options'] as List) '$o',
    ],
    correct: asIntList(j['correct']).toSet(),
    points: asInt(j['points']) ?? 1,
  );
}

@immutable
class PollTemplate {
  const PollTemplate({
    required this.id,
    required this.name,
    required this.scope,
    required this.title,
    required this.kind,
    required this.anonymity,
    required this.questions,
  });
  final int id;
  final String name;
  final String scope;
  final String title;
  final String kind;
  final String anonymity;
  final List<QuestionDraft> questions;

  factory PollTemplate.fromJson(Map<String, dynamic> j) {
    final d = asMap(j['data']);
    return PollTemplate(
      id: asInt(j['id']) ?? 0,
      name: asString(j['name']),
      scope: asString(j['scope'], 'personal'),
      title: asString(d['title']),
      kind: asString(d['kind'], 'poll'),
      anonymity: asString(d['anonymity'], 'public'),
      questions: [
        for (final q in asMapList(d['questions'])) QuestionDraft.fromJson(q),
      ],
    );
  }
}

/// A user-readable problem with a draft, or null when it can be sent.
enum DraftProblem { noTitle, tooFewOptions, noQuestionText, noCorrect }

DraftProblem? validateDraft({
  required String title,
  required bool quiz,
  required List<QuestionDraft> questions,
}) {
  if (title.trim().isEmpty) return DraftProblem.noTitle;
  for (final q in questions) {
    if (q.text.trim().isEmpty) return DraftProblem.noQuestionText;
    if (q.options.where((o) => o.trim().isNotEmpty).length < 2 ||
        q.options.any((o) => o.trim().isEmpty)) {
      return DraftProblem.tooFewOptions;
    }
    if (quiz && q.correct.isEmpty) return DraftProblem.noCorrect;
  }
  return questions.isEmpty ? DraftProblem.noQuestionText : null;
}
