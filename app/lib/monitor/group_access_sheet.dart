import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/monitor/monitor_api.dart';
import 'package:letter_signing/workspace/models.dart';

/// Manager-only editor of who may see a project group: picks a colleague and a role and
/// calls `PUT /project-groups/{id}/access` (add / change, or remove).
Future<void> showGroupAccessSheet(
  BuildContext context, {
  required MonitorApi api,
  required int groupId,
  required Future<List<UserRef>> Function() directory,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      GroupAccessSheet(api: api, groupId: groupId, directory: directory),
);

class GroupAccessSheet extends StatefulWidget {
  const GroupAccessSheet({
    super.key,
    required this.api,
    required this.groupId,
    required this.directory,
  });
  final MonitorApi api;
  final int groupId;
  final Future<List<UserRef>> Function() directory;

  @override
  State<GroupAccessSheet> createState() => _GroupAccessSheetState();
}

class _GroupAccessSheetState extends State<GroupAccessSheet> {
  late final Future<List<UserRef>> _people = widget.directory();
  int? _user;
  String _role = 'member';
  bool _busy = false;

  Future<void> _save({required bool remove}) async {
    final id = _user;
    if (id == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await widget.api.setGroupAccess(
        widget.groupId,
        add: remove ? const [] : [(userId: id, role: _role)],
        remove: remove ? [id] : const [],
      );
      messenger.showSnackBar(SnackBar(content: Text(l.monAccessSaved)));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final roles = {
      'manager': l.monRoleManager,
      'member': l.monRoleMember,
      'viewer': l.monRoleViewer,
    };
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.monAccessTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<UserRef>>(
              future: _people,
              builder: (context, snap) => DropdownButtonFormField<int>(
                key: const ValueKey('access-user'),
                isExpanded: true,
                decoration: InputDecoration(labelText: l.monAccessPick),
                items: [
                  for (final u in snap.data ?? const <UserRef>[])
                    DropdownMenuItem(value: u.id, child: Text(u.displayName)),
                ],
                onChanged: (v) => setState(() => _user = v),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const ValueKey('access-role'),
              initialValue: _role,
              items: [
                for (final e in roles.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('access-add'),
                    onPressed: _busy || _user == null
                        ? null
                        : () => unawaited(_save(remove: false)),
                    child: Text(l.monAccessAdd),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('access-remove'),
                    onPressed: _busy || _user == null
                        ? null
                        : () => unawaited(_save(remove: true)),
                    child: Text(l.monAccessRemove),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
