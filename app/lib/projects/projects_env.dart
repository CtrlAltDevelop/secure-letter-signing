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
  });

  final ProjectsApi api;
  final TasksEnv tasks;
  final LiveService live;
  final int userId;

  /// The `project.create` permission.
  final bool canCreate;

  /// Company manager: may create and rename organisation project groups.
  final bool isManager;

  /// Colleagues for the people pickers (shared with Tasks).
  Future<List<UserRef>> directory() => tasks.directory();
}
