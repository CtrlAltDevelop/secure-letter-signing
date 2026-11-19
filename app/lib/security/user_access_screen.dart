import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/security/security_api.dart';
import 'package:letter_signing/security/security_models.dart';
import 'package:letter_signing/theme/widgets.dart';

const _projectRoles = ['manager', 'member', 'viewer'];
const _chatRoles = ['admin', 'member'];

/// Manager: one user's membership of projects, customer files and group chats. Each row is
/// switched on/off or re-roled (saved at once); new rows are picked from [AccessCandidates].
class UserAccessScreen extends StatefulWidget {
  const UserAccessScreen({
    super.key,
    required this.api,
    required this.userId,
    required this.userName,
    this.isGuest = false,
  });
  final SecurityApi api;
  final int userId;
  final String userName;

  /// Guests cannot be added to customer files.
  final bool isGuest;

  @override
  State<UserAccessScreen> createState() => _UserAccessScreenState();
}

class _UserAccessScreenState extends State<UserAccessScreen> {
  UserAccess? _access;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await widget.api.access(widget.userId);
      if (mounted) setState(() => _access = a);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Sends one row and takes the server's full answer.
  Future<void> _save(String kind, AccessRow row) async {
    setState(() => _busy = true);
    try {
      final a = await widget.api.saveAccess(
        widget.userId,
        projects: kind == 'projects' ? [row] : const [],
        customers: kind == 'customers' ? [row] : const [],
        conversations: kind == 'conversations' ? [row] : const [],
      );
      if (mounted) setState(() => _access = a);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(String kind, List<String> roles) async {
    final l = AppLocalizations.of(context);
    final candidates = await widget.api.candidates();
    if (!mounted) return;
    final list = switch (kind) {
      'projects' => candidates.projects,
      'customers' => candidates.customers,
      _ => candidates.conversations,
    };
    final current = switch (kind) {
      'projects' => _access?.projects,
      'customers' => _access?.customers,
      _ => _access?.conversations,
    };
    final taken = {for (final r in current ?? const <AccessRow>[]) r.id};
    final free = [
      for (final c in list)
        if (!taken.contains(c.$1)) c,
    ];
    final picked = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.secAccessAdd),
        children: [
          if (free.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.secAccessNothingToAdd),
            ),
          for (final c in free)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Text(c.$2.isEmpty ? c.$1 : c.$2),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await _save(
      kind,
      AccessRow(id: picked.$1, role: 'member', active: true, name: picked.$2),
    );
  }

  Widget _section(
    String kind,
    String title,
    List<AccessRow> rows,
    List<String> roles, {
    bool canAdd = true,
  }) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title,
          trailing: canAdd
              ? IconButton(
                  key: ValueKey('access-add-$kind'),
                  tooltip: l.secAccessAdd,
                  icon: const Icon(Icons.add),
                  onPressed: _busy ? null : () => _add(kind, roles),
                )
              : null,
        ),
        if (rows.isEmpty)
          AppCard(child: Text(l.secAccessEmpty))
        else
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AccessTile(
                row: r,
                roles: roles,
                busy: _busy,
                onChanged: (next) => _save(kind, next),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final a = _access;
    return Scaffold(
      appBar: AppBar(title: Text(l.secAccessTitle(widget.userName))),
      body: a == null
          ? (_error != null
                ? EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: l.secLoadFailed,
                    message: '$_error',
                    action: OutlinedButton(
                      onPressed: _load,
                      child: Text(l.commonRetry),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()))
          : ListView(
              children: [
                PageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _section(
                        'projects',
                        l.secAccessProjects,
                        a.projects,
                        _projectRoles,
                      ),
                      _section(
                        'customers',
                        l.secAccessCustomers,
                        a.customers,
                        _projectRoles,
                        canAdd: !widget.isGuest,
                      ),
                      _section(
                        'conversations',
                        l.secAccessChats,
                        a.conversations,
                        _chatRoles,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

String accessRoleLabel(AppLocalizations l, String role) => switch (role) {
  'manager' => l.secRoleManager,
  'member' => l.secRoleMember,
  'viewer' => l.secRoleViewer,
  'admin' => l.secRoleAdmin,
  _ => role,
};

class _AccessTile extends StatelessWidget {
  const _AccessTile({
    required this.row,
    required this.roles,
    required this.busy,
    required this.onChanged,
  });
  final AccessRow row;
  final List<String> roles;
  final bool busy;
  final ValueChanged<AccessRow> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final role = roles.contains(row.role) ? row.role : roles.last;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.name.isEmpty ? row.id : row.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownButton<String>(
            key: ValueKey('access-role-${row.id}'),
            value: role,
            underline: const SizedBox.shrink(),
            items: [
              for (final r in roles)
                DropdownMenuItem(value: r, child: Text(accessRoleLabel(l, r))),
            ],
            onChanged: busy || !row.active
                ? null
                : (v) => v == null || v == role
                      ? null
                      : onChanged(row.copyWith(role: v)),
          ),
          Switch(
            key: ValueKey('access-active-${row.id}'),
            value: row.active,
            onChanged: busy ? null : (v) => onChanged(row.copyWith(active: v)),
          ),
        ],
      ),
    );
  }
}
