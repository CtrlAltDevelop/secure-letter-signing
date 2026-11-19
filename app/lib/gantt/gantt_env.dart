import 'package:flutter/widgets.dart' show BuildContext;

import 'package:letter_signing/gantt/gantt_api.dart';

/// What the Gantt tab needs: the API and (optionally) a way to open a task.
class GanttEnv {
  GanttEnv({required this.api, this.openTask});

  final GanttApi api;

  /// Opens the task detail (wired by the workspace); null hides "open task".
  final Future<void> Function(BuildContext context, String taskId)? openTask;
}
