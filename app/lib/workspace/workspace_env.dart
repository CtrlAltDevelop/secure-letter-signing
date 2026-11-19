import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/letters/letters_api.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/meetings/meetings_api.dart';
import 'package:letter_signing/meetings/meetings_env.dart';
import 'package:letter_signing/projects/projects_env.dart';
import 'package:letter_signing/tasks/tasks_api.dart';
import 'package:letter_signing/tasks/tasks_env.dart';

/// Codes of every module this app build knows how to show.
const knownModuleCodes = ['tasks', 'projects', 'letters', 'meetings'];

/// What every module needs after login: the API client, the one live stream, the user and
/// which modules the company plan enables. Built once by the home screen.
class WorkspaceEnv extends ChangeNotifier {
  WorkspaceEnv({
    required this.api,
    required this.live,
    required this.user,
    required this.letters,
  }) {
    letters.tasksResolver ??= () => tasks;
  }

  /// Wires the shared [LiveService] into the letters env for a signed-in user.
  factory WorkspaceEnv.forAuth(
    AuthController auth, {
    required String deviceName,
    LiveService? live,
  }) {
    final user = auth.user!;
    final shared =
        live ?? LiveService(api: auth.api, cursor: SecureCursorStore(user.id));
    return WorkspaceEnv(
      api: auth.api,
      live: shared,
      user: user,
      letters: LettersEnv(
        api: LettersApi(auth.api),
        live: shared,
        userId: user.id,
        biometrics: auth.biometrics,
        enrollBiometric: auth.enrollBiometric,
        canCreate: user.permissions.contains('letter.create'),
        isManager: user.isManager,
        canSecretariat: user.permissions.contains('letter.secretariat'),
        deviceName: deviceName,
        sessionId: () => auth.sessionId,
      ),
    );
  }

  final ApiClient api;
  final LiveService live;
  final UserInfo user;
  final LettersEnv letters;

  /// Tasks module dependencies, built on first use from the shared client and live stream.
  late final TasksEnv tasks = TasksEnv(
    api: TasksApi(api),
    live: live,
    userId: user.id,
    userName: user.fullName,
    canCreate: user.permissions.contains('task.create'),
  );

  /// Projects module dependencies, built on first use.
  late final ProjectsEnv projects = ProjectsEnv(
    api: tasks.projects,
    tasks: tasks,
    live: live,
    userId: user.id,
    canCreate: user.permissions.contains('project.create'),
    isManager: user.isManager,
  );

  /// Meetings module dependencies, built on first use.
  late final MeetingsEnv meetings = MeetingsEnv(
    api: MeetingsApi(tasks.api.workspace),
    live: live,
    userId: user.id,
    tasks: tasks,
    userName: user.fullName,
    isManager: user.isManager,
    biometrics: letters.biometrics,
  );

  Set<String> _enabled = {...knownModuleCodes};
  String _plan = '';

  /// Codes of the modules shown to this user.
  Set<String> get enabledModules => Set.unmodifiable(_enabled);
  String get plan => _plan;
  bool isEnabled(String code) => _enabled.contains(code);

  /// Reads `GET /me/modules` (`{"plan", "modules": [{"code", "enabled"}]}`). An older server
  /// (404) or a network failure leaves every known module enabled.
  Future<void> loadModules() async {
    try {
      final data = await api.call('GET', '/me/modules');
      final parsed = _parse(data);
      if (parsed == null) return;
      _enabled = parsed.enabled;
      _plan = parsed.plan;
      notifyListeners();
    } on Object {
      // Keep the all-enabled default.
    }
  }

  static ({Set<String> enabled, String plan})? _parse(Object? data) {
    if (data is! Map || data['modules'] is! List) return null;
    final enabled = <String>{};
    for (final m in data['modules'] as List) {
      if (m is Map && m['enabled'] == true && m['code'] is String) {
        enabled.add(m['code'] as String);
      }
    }
    return (enabled: enabled, plan: (data['plan'] as String?) ?? '');
  }

  /// Stops the controllers and the shared live stream.
  Future<void> disposeAll() async {
    await letters.dispose();
    await live.dispose();
    dispose();
  }
}
