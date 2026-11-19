import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/gantt/gantt_controller.dart';
import 'package:letter_signing/gantt/gantt_models.dart';
import 'package:letter_signing/gantt/gantt_painter.dart';
import 'package:letter_signing/gantt/gantt_print_screen.dart';
import 'package:letter_signing/gantt/gantt_scale.dart';
import 'package:letter_signing/gantt/gantt_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import 'gantt_fixtures.dart';

typedef _Fx = ({FakeGanttServer server, GanttController c});

Future<_Fx> _open(WidgetTester t, {bool canEdit = true}) async {
  await useTallSurface(t, const Size(1000, 900));
  final f = ganttFixture(canEdit: canEdit);
  final c = GanttController(f.api, 'p1');
  addTearDown(c.dispose);
  await t.pumpWidget(
    faMaterial(
      home: Scaffold(
        body: GanttTab(env: f.env, projectId: 'p1', controller: c),
      ),
    ),
  );
  await t.pumpAndSettle();
  return (server: f.server, c: c);
}

/// Global centre of a row's bar (or an offset from its edge), read from the live layout.
Offset _bar(WidgetTester t, _Fx fx, String taskId, {double fromRight = -1}) {
  final rows = fx.c.rows;
  final i = rows.indexWhere((r) => !r.isPhase && r.item!.taskId == taskId);
  final rect = barRect(fx.c.scale, rows[i], i)!;
  final origin = t.getTopLeft(find.byKey(const ValueKey('gantt-timeline')));
  final x = fromRight >= 0 ? rect.right - fromRight : rect.center.dx;
  return origin + Offset(x, rect.center.dy);
}

Future<void> _menu(WidgetTester t, String key, String item) async {
  await t.tap(find.byKey(ValueKey('gantt-menu-$key')));
  await t.pumpAndSettle();
  await t.tap(find.text(item));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('shows the WBS tree with codes, phases first and nested tasks', (
    t,
  ) async {
    await _open(t);
    for (final text in [
      'Design',
      'Draft',
      'Sketch',
      'Review',
      'Ship',
      '1.1.1',
      '۶۰'.isEmpty ? '' : '60%',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.byKey(const ValueKey('gantt-readonly')), findsNothing);
    expect(find.byKey(const ValueKey('gantt-add-phase')), findsOneWidget);
  });

  testWidgets(
    'a viewer gets a read-only banner, no edit controls and cannot drag',
    (t) async {
      final fx = await _open(t, canEdit: false);
      expect(find.byKey(const ValueKey('gantt-readonly')), findsOneWidget);
      expect(find.byKey(const ValueKey('gantt-add-phase')), findsNothing);
      expect(find.byKey(const ValueKey('gantt-unplanned')), findsNothing);
      await t.dragFrom(_bar(t, fx, 't3'), const Offset(84, 0));
      await t.pumpAndSettle();
      expect(fx.server.called('PUT', '/items/'), isFalse);
      // The row menu offers nothing to a viewer.
      expect(
        t
            .widget<PopupMenuButton<String>>(
              find.byKey(const ValueKey('gantt-menu-t3')),
            )
            .itemBuilder(t.element(find.byType(GanttTab))),
        isEmpty,
      );
    },
  );

  testWidgets('zoom changes the width of the time axis', (t) async {
    final fx = await _open(t);
    final daily = t.getSize(find.byKey(const ValueKey('gantt-timeline'))).width;
    await t.tap(find.text('ماهانه'));
    await t.pumpAndSettle();
    final monthly = t
        .getSize(find.byKey(const ValueKey('gantt-timeline')))
        .width;
    await t.tap(find.text('فصلی'));
    await t.pumpAndSettle();
    final quarterly = t
        .getSize(find.byKey(const ValueKey('gantt-timeline')))
        .width;
    expect(daily, greaterThan(monthly));
    expect(monthly, greaterThan(quarterly));
    expect(fx.c.zoom, GanttZoom.quarterly);
  });

  testWidgets('dragging a bar moves both dates by whole days', (t) async {
    final fx = await _open(t);
    await t.dragFrom(_bar(t, fx, 't3'), const Offset(84, 0)); // 3 days at 28 px
    await t.pumpAndSettle();
    expect(fx.server.lastBody('PUT', '/items/t3'), {
      'start_at': dayString(day(18)),
      'end_at': dayString(day(23)),
    });
  });

  testWidgets('dragging an edge resizes one date only', (t) async {
    final fx = await _open(t);
    await t.dragFrom(_bar(t, fx, 't3', fromRight: 3), const Offset(-56, 0));
    await t.pumpAndSettle();
    expect(fx.server.lastBody('PUT', '/items/t3'), {
      'start_at': dayString(day(15)),
      'end_at': dayString(day(18)),
    });
  });

  testWidgets('a failed edit shows the server message and keeps the chart', (
    t,
  ) async {
    final fx = await _open(t);
    fx.server.failDetail = 'End must not be before start';
    await t.dragFrom(_bar(t, fx, 't3'), const Offset(84, 0));
    await t.pumpAndSettle();
    expect(find.text('End must not be before start'), findsOneWidget);
    expect(find.text('Ship'), findsOneWidget);
  });

  testWidgets('add phase posts the title', (t) async {
    final fx = await _open(t);
    await t.tap(find.byKey(const ValueKey('gantt-add-phase')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('title-field')), 'Build');
    await t.tap(find.byKey(const ValueKey('title-save')));
    await t.pumpAndSettle();
    expect(fx.server.lastBody('POST', '/phases'), {'title': 'Build'});
  });

  testWidgets('rename and deactivate a phase', (t) async {
    final fx = await _open(t);
    await _menu(t, 'p1', 'تغییر نام');
    await t.enterText(find.byKey(const ValueKey('title-field')), 'Design v2');
    await t.tap(find.byKey(const ValueKey('title-save')));
    await t.pumpAndSettle();
    expect(fx.server.lastBody('PATCH', '/phases/1'), {'title': 'Design v2'});

    await _menu(t, 'p1', 'غیرفعال کردن فاز');
    await t.tap(find.byKey(const ValueKey('gantt-confirm')));
    await t.pumpAndSettle();
    expect(fx.server.lastBody('PATCH', '/phases/1'), {'active': false});
  });

  testWidgets('set dates opens the dialog and saves the range', (t) async {
    final fx = await _open(t);
    await _menu(t, 't3', 'تعیین تاریخ');
    await t.tap(find.byKey(const ValueKey('dates-save')));
    await t.pumpAndSettle();
    expect(fx.server.lastBody('PUT', '/items/t3'), {
      'start_at': dayString(day(15)),
      'end_at': dayString(day(20)),
    });

    await _menu(t, 't3', 'تعیین تاریخ');
    await t.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byIcon(Icons.clear),
          )
          .first,
    );
    await t.pump();
    await t.tap(find.byKey(const ValueKey('dates-save')));
    await t.pumpAndSettle();
    expect(fx.server.lastBody('PUT', '/items/t3'), {
      'start_at': null,
      'end_at': dayString(day(20)),
    });
  });

  testWidgets('indent and outdent send the new parent or level', (t) async {
    final fx = await _open(t);
    await _menu(t, 't2', 'زیرمجموعه (تورفتگی)');
    expect(fx.server.lastBody('PUT', '/items/t2'), {'parent_task_id': 't1'});
    await _menu(t, 't4', 'خروج از زیرمجموعه');
    expect(fx.server.lastBody('PUT', '/items/t4'), {
      'phase_id': 1,
      'parent_task_id': null,
    });
  });

  testWidgets('moving a task up reorders its siblings through /reorder', (
    t,
  ) async {
    final fx = await _open(t);
    await _menu(t, 't2', 'بالا بردن');
    expect(fx.server.lastBody('POST', '/reorder'), {
      'items': [
        {'task_id': 't2', 'phase_id': 1, 'parent_task_id': null},
        {'task_id': 't1', 'phase_id': 1, 'parent_task_id': null},
      ],
    });
  });

  testWidgets('removing from the plan asks first, then deactivates the row', (
    t,
  ) async {
    final fx = await _open(t);
    await _menu(t, 't3', 'حذف از برنامه');
    expect(fx.server.called('PUT', '/items/t3'), isFalse);
    await t.tap(find.byKey(const ValueKey('gantt-confirm')));
    await t.pumpAndSettle();
    expect(fx.server.lastBody('PUT', '/items/t3'), {'active': false});
  });

  testWidgets(
    'dependencies: conflict is flagged, one can be removed and one added',
    (t) async {
      final fx = await _open(t);
      await _menu(t, 't2', 'وابستگی‌ها');
      expect(find.text('Draft'), findsWidgets);
      expect(
        find.text('تداخل: این وظیفه زودتر از پایان پیش‌نیاز شروع می‌شود'),
        findsOneWidget,
      );

      await t.tap(find.byKey(const ValueKey('dep-remove-12')));
      await t.pumpAndSettle();
      expect(fx.server.called('POST', '/links/12/deactivate'), isTrue);

      await t.tap(find.byKey(const ValueKey('dep-add')));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Sketch').last);
      await t.pumpAndSettle();
      expect(fx.server.lastBody('POST', '/links'), {
        'predecessor_task_id': 't4',
        'successor_task_id': 't2',
      });
    },
  );

  testWidgets('the unplanned panel adds a task into a phase', (t) async {
    final fx = await _open(t);
    await t.tap(find.byKey(const ValueKey('gantt-unplanned')));
    await t.pumpAndSettle();
    expect(find.text('Loose task'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('unplanned-add-u1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('plan-phase')));
    await t.pumpAndSettle();
    await t.tap(find.text('Design').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('plan-add')));
    await t.pumpAndSettle();
    expect(fx.server.lastBody('PUT', '/items/u1'), {'phase_id': 1});
  });

  testWidgets('print screen paginates the rows and offers the print action', (
    t,
  ) async {
    await useTallSurface(t, const Size(1200, 900));
    final f = ganttFixture();
    await t.pumpWidget(
      faMaterial(
        home: GanttPrintScreen(api: f.api, projectId: 'p1'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(GanttPrintPage), findsOneWidget);
    expect(
      t
          .widget<IconButton>(find.byKey(const ValueKey('gantt-print-go')))
          .onPressed,
      isNotNull,
    );
    expect(f.server.called('GET', '/print'), isTrue);
  });
}
