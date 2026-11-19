import 'package:material_ui/material_ui.dart';

/// Something a calendar entry, search hit, bookmark or pin points at: the server's module
/// code, its kind, the module object id (task id, letter id ...) and the subject id.
@immutable
class OpenTarget {
  const OpenTarget({
    required this.module,
    required this.id,
    this.kind = '',
    this.subjectId = '',
  });

  final String module;
  final String id;
  final String kind;
  final String subjectId;
}

/// Opens [target] with the right screen (tests replace it with a recorder).
typedef OpenFn = Future<void> Function(BuildContext context, OpenTarget target);

/// A module's own opener, registered on `WorkspaceEnv.openers`; false when it cannot show it.
typedef TargetOpener = Future<bool> Function(
  BuildContext context,
  OpenTarget target,
);
