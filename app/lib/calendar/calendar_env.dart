import 'package:letter_signing/calendar/calendar_api.dart';
import 'package:letter_signing/crm/crm_api.dart';
import 'package:letter_signing/projects/projects_api.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/workspace/open_target.dart';

/// What the calendar screens need: the API, lookups for the filters, how to open an item and
/// whether the user holds `monitor.view` (team calendar, colleague inbox).
class CalendarEnv {
  CalendarEnv({
    required this.api,
    required this.tasks,
    required this.projects,
    required this.open,
    this.crm,
    this.canMonitor = false,
    this.userId = 0,
  });

  final CalendarApi api;
  final TasksEnv tasks;
  final ProjectsApi projects;
  final OpenFn open;
  final CrmApi? crm;
  final bool canMonitor;
  final int userId;
}
