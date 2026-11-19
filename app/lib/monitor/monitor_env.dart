import 'package:letter_signing/monitor/monitor_api.dart';
import 'package:letter_signing/workspace/models.dart';

/// What the monitoring screens need: the API, whether the user holds `monitor.view` and which
/// modules are on (tabs of a switched-off module are hidden).
class MonitorEnv {
  MonitorEnv({
    required this.api,
    required this.canMonitor,
    this.isEnabled = _all,
    this.directory,
  });

  final MonitorApi api;
  final bool canMonitor;
  final bool Function(String module) isEnabled;

  /// Colleagues for pickers (optional).
  final Future<List<UserRef>> Function()? directory;

  static bool _all(String _) => true;
}
