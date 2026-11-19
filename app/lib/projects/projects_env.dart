import 'package:flutter/widgets.dart' show Widget;

import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/projects/projects_api.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/workspace/models.dart';

/// What the Projects screens need: the API, the Tasks env (task screens are reused inside a
/// project), the shared live stream and who the signed-in user is.
class ProjectsEnv {
  ProjectsEnv({
    required this.api,
    required this.tasks,
    required this.live,
    required this.userId,
    this.canCreate = true,
    this.isManager = false,
    this.chatTab,
    this.ganttTab,
  });

  final ProjectsApi api;
  final TasksEnv tasks;
  final LiveService live;
  final int userId;

  /// The `project.create` permission.
  final bool canCreate;

  /// Company manager: may create and rename organisation project groups.
  final bool isManager;

  /// Builds the chat tab of a project (null while the chat module is off or unwired).
  final Widget? Function(String projectId)? chatTab;

  /// Builds the Gantt tab of a project; null (or a null result) hides the tab, e.g. while the
  /// `gantt` module is off.
  final Widget? Function(String projectId)? ganttTab;

  /// Colleagues for the people pickers (shared with Tasks).
  Future<List<UserRef>> directory() => tasks.directory();
}
