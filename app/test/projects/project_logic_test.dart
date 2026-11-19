import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/project_controller.dart';
import 'package:letter_signing/tasks/models.dart';

import 'project_fixtures.dart';

TaskBrief _t(String id, int col, int rank, {String? due, String? updated}) =>
    TaskBrief.fromJson({
      ...boardTask(id, col, rank, dueAt: due),
      'updated_at': updated ?? '2026-01-01T00:00:00Z',
    });

BoardColumn _col(int id, List<TaskBrief> tasks) =>
    BoardColumn(id: id, title: 'c$id', tasks: tasks);

List<String> _ids(BoardColumn c) => [for (final t in c.tasks) t.id];

void main() {
  group('applyMove', () {
    final board = [
      _col(1, [_t('a', 1, 1), _t('b', 1, 2)]),
      _col(2, [_t('c', 2, 1)]),
    ];

    test('moves to another column before a card', () {
      final next = applyMove(board, 'a', 2, beforeId: 'c');
      expect(_ids(next[0]), ['b']);
      expect(_ids(next[1]), ['a', 'c']);
      expect(next[1].tasks.first.columnId, 2);
    });

    test('appends when no before id and reorders inside a column', () {
      expect(_ids(applyMove(board, 'a', 2)[1]), ['c', 'a']);
      expect(_ids(applyMove(board, 'a', 1)[0]), ['b', 'a']);
      expect(_ids(applyMove(board, 'b', 1, beforeId: 'a')[0]), ['b', 'a']);
    });

    test('unknown task or column returns the same board', () {
      expect(identical(applyMove(board, 'zz', 2), board), isTrue);
      expect(identical(applyMove(board, 'a', 9), board), isTrue);
    });

    test('percentDone ignores cancelled tasks', () {
      final c = _col(1, [
        TaskBrief.fromJson(boardTask('x', 1, 1, status: 'done')),
        TaskBrief.fromJson(boardTask('y', 1, 2)),
        TaskBrief.fromJson(boardTask('z', 1, 3, status: 'cancelled')),
      ]);
      expect(c.percentDone, 50);
      expect(_col(1, const []).percentDone, 0);
    });
  });

  group('sortTasks', () {
    final tasks = [
      _t(
        'a',
        1,
        2,
        due: '2026-05-02T00:00:00Z',
        updated: '2026-01-03T00:00:00Z',
      ),
      _t(
        'b',
        1,
        1,
        due: '2026-05-01T00:00:00Z',
        updated: '2026-01-02T00:00:00Z',
      ),
      _t('c', 1, 3, updated: '2026-01-01T00:00:00Z'),
    ];
    List<String> order(ColumnSort s) => [
      for (final t in sortTasks(tasks, s)) t.id,
    ];

    test('by rank, due and updated in both directions', () {
      expect(order(ColumnSort.manual), ['b', 'a', 'c']);
      expect(order(ColumnSort.createdDesc), ['c', 'a', 'b']);
      expect(order(ColumnSort.dueAsc), ['b', 'a', 'c']);
      expect(order(ColumnSort.dueDesc), ['a', 'b', 'c']);
      expect(order(ColumnSort.updatedAsc), ['c', 'b', 'a']);
      expect(order(ColumnSort.updatedDesc), ['a', 'b', 'c']);
    });
  });

  group('ProjectDraft', () {
    test('requires a name and an end after the start', () {
      expect(const ProjectDraft().issues, {ProjectIssue.nameMissing});
      final d = ProjectDraft(
        name: 'x',
        startDate: DateTime(2026, 5, 2),
        endDate: DateTime(2026, 5, 1),
      );
      expect(d.issues, {ProjectIssue.endBeforeStart});
    });

    test('create body carries date-only strings and members', () {
      final d = ProjectDraft(
        name: ' P ',
        startDate: DateTime(2026, 3, 21),
        members: const [MemberDraft(2, ProjectRole.manager)],
      );
      final j = d.toCreateJson();
      expect(j['name'], 'P');
      expect(j['start_date'], '2026-03-21');
      expect(j['end_date'], isNull);
      expect(j['members'], [
        {'user_id': 2, 'role': 'manager'},
      ]);
    });
  });
}
