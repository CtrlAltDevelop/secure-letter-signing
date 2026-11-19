import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/polls/models.dart';
import 'package:letter_signing/polls/poll_create_screen.dart';
import 'package:letter_signing/polls/poll_screen.dart';
import 'package:letter_signing/polls/polls_section.dart';

import '../helpers.dart';
import '../letters/fakes.dart' show useTallSurface;
import 'polls_fixtures.dart';

const _sizes = [Size(375, 812), Size(844, 390)];

Future<void> _show(WidgetTester t, Widget w, Size size) async {
  await useTallSurface(t, size);
  await t.pumpWidget(faMaterial(home: w));
  await t.pumpAndSettle();
}

void main() {
  test('validateDraft flags missing parts', () {
    const ok = QuestionDraft(text: 'q', options: ['a', 'b'], correct: {0});
    expect(
      validateDraft(title: '', quiz: false, questions: [ok]),
      DraftProblem.noTitle,
    );
    expect(
      validateDraft(
        title: 't',
        quiz: false,
        questions: [
          ok.copyWith(options: ['a', '']),
        ],
      ),
      DraftProblem.tooFewOptions,
    );
    expect(
      validateDraft(
        title: 't',
        quiz: true,
        questions: [ok.copyWith(correct: {})],
      ),
      DraftProblem.noCorrect,
    );
    expect(validateDraft(title: 't', quiz: true, questions: [ok]), isNull);
  });

  for (final size in _sizes) {
    testWidgets('create a quiz and save a template at $size', (t) async {
      final s = FakePollsServer();
      await _show(
        t,
        PollCreateScreen(env: pollsEnv(s), targetSubjectId: targetSubject),
        size,
      );
      await t.enterText(find.byKey(const ValueKey('poll-title-0')), 'Quiz 1');
      await t.tap(find.text('آزمون'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('q0-text')), 'Capital?');
      await t.pump();
      await t.enterText(find.byKey(const ValueKey('q0-opt-0-2')), 'Tehran');
      await t.pump();
      await t.enterText(find.byKey(const ValueKey('q0-opt-1-2')), 'Rasht');
      await t.pump();
      await t.ensureVisible(find.byKey(const ValueKey('q0-correct-0')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('q0-correct-0')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('poll-save-template')));
      await t.pumpAndSettle();
      await t.tap(find.text('ذخیره').last);
      await t.pumpAndSettle();
      expect(s.templates.single['name'], 'Quiz 1');
      await t.pump(const Duration(seconds: 6)); // let the snackbar go
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('poll-create')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(find.byKey(const ValueKey('poll-create')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('poll-create')));
      await t.pumpAndSettle();
      final body = s.lastBody('POST', '/polls')! as Map;
      expect(body['kind'], 'quiz');
      expect(body['target_subject_id'], targetSubject);
      final q = (body['questions'] as List).single as Map;
      expect(q['correct'], [0]);
      expect(q['options'], ['Tehran', 'Rasht']);
      expect(t.takeException(), isNull);
    });

    testWidgets('template fills the form at $size', (t) async {
      final s = FakePollsServer()
        ..templates.add({
          'id': 1,
          'name': 'T',
          'scope': 'personal',
          'active': true,
          'data': {
            'title': 'From template',
            'kind': 'poll',
            'anonymity': 'anonymous_to_all',
            'questions': [
              {
                'text': 'Tq',
                'options': ['x', 'y'],
              },
            ],
          },
        });
      await _show(
        t,
        PollCreateScreen(env: pollsEnv(s), targetSubjectId: targetSubject),
        size,
      );
      await t.tap(find.byKey(const ValueKey('poll-templates')));
      await t.pumpAndSettle();
      await t.tap(find.text('T'));
      await t.pumpAndSettle();
      expect(find.text('From template'), findsOneWidget);
      expect(find.text('Tq'), findsOneWidget);
    });
  }

  testWidgets('vote, results bars, then change answer', (t) async {
    final s = FakePollsServer();
    await _show(t, PollScreen(env: pollsEnv(s), pollId: 'p1'), _sizes[0]);
    expect(find.text('ثبت پاسخ'), findsOneWidget);
    expect(find.text('نتایج'), findsNothing);
    await t.tap(find.text('Pizza'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('poll-submit')));
    await t.pumpAndSettle();
    expect(s.lastBody('POST', '/submit'), {
      'answers': [
        {
          'question_id': 7,
          'option_ids': [70],
        },
      ],
    });
    expect(find.text('نتایج'), findsOneWidget);
    expect(find.text('تغییر پاسخ'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    expect(find.text('۱۰۰٪', findRichText: true), findsNothing);
    await t.tap(find.text('Kebab').first);
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('poll-submit')));
    await t.tap(find.byKey(const ValueKey('poll-submit')));
    await t.pumpAndSettle();
    expect(s.answers.single['option_ids'], [71]);
  });

  testWidgets('voters shown only when the server sends them', (t) async {
    final s = FakePollsServer()
      ..submitted = true
      ..answers = [
        {
          'question_id': 7,
          'option_ids': [70],
        },
      ];
    await _show(t, PollScreen(env: pollsEnv(s), pollId: 'p1'), _sizes[0]);
    expect(find.text('Ali'), findsNothing);
    s.moderator = true;
    await t.pumpWidget(const SizedBox());
    await _show(t, PollScreen(env: pollsEnv(s), pollId: 'p1'), _sizes[0]);
    expect(find.text('Ali'), findsOneWidget);
  });

  testWidgets('manager ends the poll; quiz scores and print show', (t) async {
    final s = FakePollsServer()
      ..moderator = true
      ..submitted = true
      ..poll['kind'] = 'quiz'
      ..answers = [
        {
          'question_id': 7,
          'option_ids': [70],
        },
      ];
    await _show(t, PollScreen(env: pollsEnv(s), pollId: 'p1'), _sizes[1]);
    await t.scrollUntilVisible(find.text('امتیاز شرکت‌کنندگان'), 200);
    await t.tap(find.byKey(const ValueKey('poll-close')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('poll-close-yes')));
    await t.pumpAndSettle();
    expect(s.where('POST', '/close'), hasLength(1));
    expect(find.byKey(const ValueKey('poll-close')), findsNothing);
    await t.ensureVisible(find.byKey(const ValueKey('poll-print')));
    await t.tap(find.byKey(const ValueKey('poll-print')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('poll-print-go')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('section lists polls of the target', (t) async {
    final s = FakePollsServer();
    await _show(
      t,
      Scaffold(
        body: PollsSection(env: pollsEnv(s), targetSubjectId: targetSubject),
      ),
      _sizes[0],
    );
    expect(find.text('Lunch'), findsOneWidget);
    expect(s.calls.first.url.queryParameters['target_subject'], targetSubject);
  });
}
