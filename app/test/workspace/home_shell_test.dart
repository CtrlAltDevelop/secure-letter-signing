import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/meetings/meetings_screen.dart';
import 'package:letter_signing/screens/home_screen.dart';
import 'package:letter_signing/projects/projects_screen.dart';
import 'package:letter_signing/tasks/tasks_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';

Map<String, dynamic> _user({bool manager = false}) => {
  'id': 2,
  'email': 'me@x.test',
  'full_name': 'Me',
  'title': '',
  'department': '',
  'department_id': null,
  'is_manager': manager,
  'is_active': true,
  'has_signing_pin': true,
  'permissions': ['letter.see'],
};

Future<AuthController> _auth({
  bool manager = false,
  List<Map<String, Object>>? modules,
}) async {
  final f = fakeApi((req, _) {
    final path = req.url.path;
    if (path == '/api/auth/refresh') {
      return json({'access': 'a', 'refresh': 'r'});
    }
    if (path == '/api/me') return json(_user(manager: manager));
    if (path == '/api/me/modules') {
      return modules == null
          ? json({'detail': 'Not found'}, 404)
          : json({'plan': 'pro', 'modules': modules});
    }
    if (path == '/api/me/sessions') return json([]);
    return json([]);
  });
  final auth = AuthController(f.client, biometrics: FakeBiometrics());
  await auth.restore();
  return auth;
}

Future<void> _pump(WidgetTester t, AuthController auth, Size size) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  final live = FakeLive(auth.api);
  await t.pumpWidget(faApp(HomeScreen(auth: auth, live: live)));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'phone bar: Tasks, Projects, Letters, More; More lists the rest',
    (t) async {
      final auth = await _auth(manager: true);
      await _pump(t, auth, const Size(400, 800));
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('وظایف'),
        ),
        findsOneWidget,
      );
      final labels = t
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .map((d) => d.label)
          .toList();
      expect(labels, ['وظایف', 'پروژه‌ها', 'نامه‌ها', 'بیشتر']);

      await t.tap(find.text('بیشتر'));
      await t.pumpAndSettle();
      for (final label in [
        'جلسات',
        'پروفایل',
        'برچسب‌ها',
        'دستگاه‌ها',
        'همه نامه‌ها',
        'مدیریت',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    },
  );

  testWidgets('Tasks is the first tab and shows its inbox', (t) async {
    final auth = await _auth();
    await _pump(t, auth, const Size(400, 800));
    expect(find.byType(TasksScreen), findsOneWidget);
    expect(find.text('وظیفه‌ای در صندوق نیست'), findsOneWidget);
    expect(find.text('به‌زودی'), findsNothing);
  });

  testWidgets('Meetings sits in More after Letters and opens its screen', (
    t,
  ) async {
    final auth = await _auth();
    await _pump(t, auth, const Size(400, 800));
    await t.tap(find.text('بیشتر'));
    await t.pumpAndSettle();
    await t.tap(find.text('جلسات'));
    await t.pumpAndSettle();
    expect(find.byType(MeetingsScreen), findsOneWidget);
  });

  testWidgets('Projects tab shows the real Projects screen', (t) async {
    final auth = await _auth();
    await _pump(t, auth, const Size(400, 800));
    await t.tap(find.text('پروژه‌ها'));
    await t.pumpAndSettle();
    expect(find.byType(ProjectsScreen), findsOneWidget);
    expect(find.text('هنوز پروژه‌ای ندارید'), findsOneWidget);
    expect(find.text('به‌زودی'), findsNothing);
  });

  testWidgets('disabled modules leave the bar; More stays', (t) async {
    final auth = await _auth(
      modules: [
        {'code': 'letters', 'enabled': true},
        {'code': 'tasks', 'enabled': false},
        {'code': 'projects', 'enabled': false},
      ],
    );
    await _pump(t, auth, const Size(400, 800));
    final labels = t
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(labels, ['نامه‌ها', 'بیشتر']);
  });

  testWidgets('wide screens use the rail with every destination', (t) async {
    final auth = await _auth(manager: true);
    await _pump(t, auth, const Size(1200, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final rail = t.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations.length, 9);
  });
}
