import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/workspace/models.dart';

import 'task_fixtures.dart';

void main() {
  group('TaskBrief', () {
    test('parses every field of a list row', () {
      final t = TaskBrief.fromJson(
        briefTask(
          't1',
          title: 'Write report',
          priority: 'high',
          progress: 40,
          dueAt: '2026-03-01T10:00:00Z',
          unseen: true,
          labelIds: [3],
          checklist: {'done': 1, 'total': 4},
        ),
      );
      expect(t.title, 'Write report');
      expect(t.priority, 'high');
      expect(t.progress, 40);
      expect(t.dueAt, DateTime.utc(2026, 3, 1, 10));
      expect(t.unseen, isTrue);
      expect(t.labelIds, [3]);
      expect(t.checklist.done, 1);
      expect(t.checklist.total, 4);
      expect(t.ownerIds, [2]);
    });

    test('tolerates missing and mistyped fields', () {
      final t = TaskBrief.fromJson({
        'id': 'x',
        'progress': 400,
        'checklist': 'oops',
        'owner_ids': 'nope',
      });
      expect(t.title, '');
      expect(t.status, TaskStatus.open);
      expect(t.priority, TaskPriority.normal);
      expect(t.progress, 100);
      expect(t.checklist.total, 0);
      expect(t.ownerIds, isEmpty);
      expect(t.dueAt, isNull);
    });

    test('overdue only while active and past due', () {
      final now = DateTime.utc(2026, 3, 2);
      TaskBrief task(String status, {bool allDay = false, String? due}) =>
          TaskBrief.fromJson(
            briefTask('a', status: status, allDay: allDay, dueAt: due),
          );
      expect(task('open', due: '2026-03-01T00:00:00Z').isOverdue(now), isTrue);
      expect(task('done', due: '2026-03-01T00:00:00Z').isOverdue(now), isFalse);
      expect(task('open', due: '2026-03-05T00:00:00Z').isOverdue(now), isFalse);
      expect(task('open').isOverdue(now), isFalse);
      // An all-day date is overdue only once that local day is over.
      final day = DateTime(2026, 3, 2, 12).toUtc().toIso8601String();
      expect(
        task(
          'open',
          allDay: true,
          due: day,
        ).isOverdue(DateTime(2026, 3, 2, 23)),
        isFalse,
      );
      expect(
        task('open', allDay: true, due: day).isOverdue(DateTime(2026, 3, 3, 1)),
        isTrue,
      );
    });
  });

  group('TaskOut actions', () {
    TaskOut task(String status, Map<String, dynamic> can) =>
        TaskOut.fromJson(fullTask('a', status: status, can: can));

    test('complete needs an open task and permission', () {
      expect(task('open', canJson(progress: true)).showComplete, isTrue);
      expect(task('open', canJson()).showComplete, isFalse);
      expect(task('done', canJson(progress: true)).showComplete, isFalse);
      expect(
        task('open', canJson(progress: true, complete: false)).showComplete,
        isFalse,
      );
    });

    test('decision only while awaiting approval for approvers', () {
      expect(
        task('awaiting_approval', canJson(approve: true)).showDecision,
        isTrue,
      );
      expect(task('open', canJson(approve: true)).showDecision, isFalse);
      expect(task('awaiting_approval', canJson()).showDecision, isFalse);
    });

    test('reopen and cancel follow the status', () {
      expect(task('done', canJson(edit: true)).showReopen, isTrue);
      expect(task('cancelled', canJson(edit: true)).showReopen, isTrue);
      expect(task('open', canJson(edit: true)).showReopen, isFalse);
      expect(task('open', canJson(edit: true)).showCancel, isTrue);
      expect(task('done', canJson(edit: true)).showCancel, isFalse);
      expect(task('open', canJson()).showCancel, isFalse);
    });

    test('progress slider only in manual mode', () {
      final manual = TaskOut.fromJson(
        fullTask('a', can: canJson(progress: true)),
      );
      final auto = TaskOut.fromJson(
        fullTask('a', can: canJson(progress: true), progressMode: 'checklist'),
      );
      expect(manual.progressEditable, isTrue);
      expect(auto.progressEditable, isFalse);
    });

    test('parses people, approvers in order, checklist and can', () {
      final t = TaskOut.fromJson(
        fullTask(
          'a',
          description: 'Hello',
          items: [checkItem(1, 'one', done: true), checkItem(2, 'two')],
          approvers: [
            {'user': carol, 'position': 2, 'decision': 'pending'},
            {'user': bob, 'position': 1, 'decision': 'approved'},
          ],
          status: 'awaiting_approval',
        ),
      );
      expect(t.description, 'Hello');
      expect(t.creator?.id, 2);
      expect(t.approvers.map((a) => a.user.id), [3, 4]);
      expect(t.approvers.first.approved, isTrue);
      expect(t.currentApprover?.user.id, 4);
      expect(t.checklistItems.map((i) => i.done), [true, false]);
      expect(t.can.edit, isTrue);
    });
  });

  group('comments', () {
    test('nested replies are flattened with their parent id', () {
      final all = CommentInfo.parseAll([
        commentJson(1, 'a', replies: [commentJson(2, 'b', author: bob)]),
        commentJson(3, 'c'),
      ]);
      expect(all.map((c) => c.id), [1, 2, 3]);
      expect(all[1].parentId, 1);
      expect(all[1].author.id, 3);
    });

    test('flat lists keep parent ids and inactive ones are dropped', () {
      final all = CommentInfo.parseAll([
        commentJson(1, 'a'),
        {...commentJson(2, 'b', parentId: 1), 'progress_snapshot': 30},
        {...commentJson(3, 'gone'), 'active': false},
      ]);
      expect(all.map((c) => c.id), [1, 2]);
      expect(all[1].parentId, 1);
      expect(all[1].progress, 30);
    });
  });

  group('TaskDraft', () {
    test('create body carries UTC ISO dates and trimmed checklist', () {
      final local = DateTime(2026, 3, 1, 9, 30);
      final json = TaskDraft(
        title: '  Plan  ',
        dueAt: local,
        ownerIds: const [2],
        checklist: const ['a', '  ', 'b'],
      ).toCreateJson();
      expect(json['title'], 'Plan');
      expect(json['due_at'], local.toUtc().toIso8601String());
      expect(json.containsKey('start_at'), isFalse);
      expect(json['checklist'], ['a', 'b']);
      expect(json['owner_ids'], [2]);
      expect(json['project_id'], isNull);
    });

    test('issues: title, owner, due before start', () {
      expect(const TaskDraft().issues, {
        DraftIssue.titleMissing,
        DraftIssue.noOwner,
      });
      final bad = TaskDraft(
        title: 'x',
        ownerIds: const [1],
        startAt: DateTime(2026, 3, 2),
        dueAt: DateTime(2026, 3, 1),
      );
      expect(bad.issues, {DraftIssue.dueBeforeStart});
      expect(bad.copyWith(clearDue: true).issues, isEmpty);
    });

    test(
      'patch holds only changed fields and sends null for a cleared date',
      () {
        final original = TaskOut.fromJson(
          fullTask('a', title: 'Old', dueAt: '2026-03-01T10:00:00Z'),
        );
        final draft = TaskDraft.fromTask(original);
        expect(draft.patchAgainst(original), isEmpty);
        final patch = draft
            .copyWith(title: 'New', clearDue: true)
            .patchAgainst(original);
        expect(patch, {'title': 'New', 'due_at': null});
      },
    );

    test('peopleChanged compares owners, approvers and followers', () {
      final original = TaskOut.fromJson(fullTask('a'));
      final draft = TaskDraft.fromTask(original);
      expect(draft.peopleChanged(original), isFalse);
      expect(draft.copyWith(followerIds: [3]).peopleChanged(original), isTrue);
    });
  });
}
