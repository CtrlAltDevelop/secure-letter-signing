import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/gantt/gantt_models.dart';
import 'package:letter_signing/gantt/gantt_plan.dart';
import 'package:letter_signing/gantt/gantt_print_screen.dart';
import 'package:letter_signing/gantt/gantt_scale.dart';

import 'gantt_fixtures.dart';

GanttChart _chart() => GanttChart.fromJson(chartJson());

void main() {
  test('days are UTC midnights and round trip as YYYY-MM-DD', () {
    final d = parseDay('2026-03-21')!;
    expect(d.isUtc, isTrue);
    expect(dayString(d), '2026-03-21');
    expect(daysBetween(d, parseDay('2026-04-01')!), 11);
    expect(parseDay(null), isNull);
  });

  test('rows merge phases and tasks in numeric WBS order', () {
    final rows = chartRows(_chart());
    expect([for (final r in rows) r.wbs], ['1', '1.1', '1.1.1', '1.2', '2']);
    expect(rows.first.isPhase, isTrue);
    final big = GanttChart.fromJson({
      ...chartJson(),
      'phases': <Object>[],
      'items': [
        itemJson('a', '10', 'A', level: 1, phase: null),
        itemJson('b', '2', 'B', level: 1, phase: null),
      ],
    });
    expect([for (final r in chartRows(big)) r.wbs], ['2', '10']);
  });

  test('weekend marks follow the server index (0 = Saturday, Friday = 6)', () {
    const marks = GanttCalendarMarks();
    expect(marks.isWeekend(DateTime.utc(2026, 3, 20)), isTrue); // Friday
    expect(marks.isWeekend(DateTime.utc(2026, 3, 21)), isFalse); // Saturday
    final custom = GanttCalendarMarks(
      weekend: const [5, 6],
      holidays: {DateTime.utc(2026, 3, 25): 'x'},
    );
    expect(custom.isWeekend(DateTime.utc(2026, 3, 19)), isTrue); // Thursday
    expect(custom.isHoliday(DateTime.utc(2026, 3, 25)), isTrue);
  });

  test('the axis covers whole Jalali months and the headers tile it', () {
    // 2026-03-21 is 1 Farvardin 1405; 2026-05-10 is 20 Ordibehesht.
    final scale = GanttScale.fit(
      DateTime.utc(2026, 3, 25),
      DateTime.utc(2026, 5, 10),
      GanttZoom.daily,
    );
    expect(scale.origin, DateTime.utc(2026, 3, 21));
    expect(scale.days, 31 + 31); // Farvardin + Ordibehesht
    expect([for (final s in scale.top) s.label], ['فروردین', 'اردیبهشت']);
    for (final zoom in GanttZoom.values) {
      final z = GanttScale(origin: scale.origin, days: scale.days, zoom: zoom);
      for (final row in [z.top, z.bottom]) {
        expect(
          row.fold<int>(0, (a, s) => a + s.days),
          scale.days,
          reason: '$zoom',
        );
        for (var i = 1; i < row.length; i++) {
          expect(row[i].startDay, row[i - 1].startDay + row[i - 1].days);
        }
      }
    }
  });

  test(
    'zoom changes the day width; monthly names months, quarterly names seasons',
    () {
      final d = DateTime.utc(2026, 3, 25);
      final e = DateTime.utc(2026, 9, 30);
      final daily = GanttScale.fit(d, e, GanttZoom.daily);
      final monthly = GanttScale.fit(d, e, GanttZoom.monthly);
      final quarterly = GanttScale.fit(d, e, GanttZoom.quarterly);
      expect(daily.width, greaterThan(monthly.width));
      expect(monthly.width, greaterThan(quarterly.width));
      expect(monthly.bottom.first.label, 'فروردین');
      expect(
        [for (final s in quarterly.bottom) s.label],
        ['بهار', 'تابستان', 'پاییز'],
      );
      expect(monthly.top.single.label, '۱۴۰۵');
      expect(daily.dayUnder(daily.x(d) + 1), d);
    },
  );

  test(
    'indent nests under the sibling above; the first sibling cannot indent',
    () {
      final c = _chart();
      expect(indentBody(c, c.item('t2')!), {'parent_task_id': 't1'});
      expect(indentBody(c, c.item('t1')!), isNull);
    },
  );

  test('outdent lifts to the parent\'s level; top level cannot outdent', () {
    final c = _chart();
    expect(outdentBody(c, c.item('t4')!), {
      'phase_id': 1,
      'parent_task_id': null,
    });
    expect(outdentBody(c, c.item('t2')!), isNull);
  });

  test('moving reorders siblings only and refuses to leave the list', () {
    final c = _chart();
    expect(moveItems(c, c.item('t2')!, -1)!.map((e) => e['task_id']), [
      't2',
      't1',
    ]);
    expect(moveItems(c, c.item('t1')!, -1), isNull);
    expect(moveItems(c, c.item('t2')!, 1), isNull);
    expect(movePhases(c, 1, 1), isNull);
  });

  test('shifting and resizing keep end >= start', () {
    final c = _chart();
    final t1 = c.item('t1')!;
    expect(shiftBody(t1, 2), {
      'start_at': dayString(day(3)),
      'end_at': dayString(day(7)),
    });
    expect(resizeBody(t1, startEdge: true, days: 99), {
      'start_at': dayString(day(5)),
      'end_at': dayString(day(5)),
    });
    expect(resizeBody(t1, startEdge: false, days: -99), {
      'start_at': dayString(day(1)),
      'end_at': dayString(day(1)),
    });
    expect(
      resizeBody(t1, startEdge: false, days: 2)['end_at'],
      dayString(day(7)),
    );
  });

  test(
    'dependency candidates exclude the task itself and existing predecessors',
    () {
      final c = _chart();
      expect(
        {for (final i in predecessorCandidates(c, 't2')) i.taskId},
        {'t4'},
      );
      expect(
        {for (final i in predecessorCandidates(c, 't3')) i.taskId},
        {'t1', 't4', 't2'},
      );
    },
  );

  test('printing splits long charts into pages of rowsPerPage rows', () {
    final rows = [
      for (var i = 0; i < rowsPerPage() * 2 + 3; i++)
        GanttPrintRow(
          kind: 'task',
          wbs: '${i + 1}',
          level: 1,
          title: 't$i',
          progress: 0,
        ),
    ];
    final pages = paginateRows(rows);
    expect(pages.length, 3);
    expect(pages.last.length, 3);
    expect(paginateRows(const []).length, 1);
  });
}
