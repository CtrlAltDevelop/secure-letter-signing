import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/screens/auth_screens.dart';

/// Manager-only: people & permissions, signup switches, invitation codes.
class AdminTab extends StatefulWidget {
  const AdminTab({super.key, required this.auth});
  final AuthController auth;

  @override
  State<AdminTab> createState() => _AdminTabState();
}

class _AdminTabState extends State<AdminTab> {
  late Future<_AdminData> _data = _load();

  Future<_AdminData> _load() async {
    final api = widget.auth.api;
    final results = await Future.wait([
      api.call('GET', '/manage/users'),
      api.call('GET', '/manage/permissions'),
      api.call('GET', '/manage/company'),
      api.call('GET', '/manage/invites'),
    ]);
    return _AdminData(
      users: (results[0] as List)
          .map((e) => UserInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      permissionCodes: (results[1] as List)
          .map((e) => (e as Map)['code'] as String)
          .toList(),
      company: results[2] as Map<String, dynamic>,
      invites: List<Map<String, dynamic>>.from(results[3] as List),
    );
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<void> _call(String method, String path, [Object? body]) async {
    final ok = await runGuarded(
      context,
      () => widget.auth.api.call(method, path, body: body),
    );
    if (ok && mounted) _reload();
  }

  Future<void> _resetToken(UserInfo user) async {
    String? token;
    final ok = await runGuarded(context, () async {
      final res = await widget.auth.api.call(
        'POST',
        '/manage/users/${user.id}/reset-token',
      ) as Map<String, dynamic>;
      token = res['token'] as String;
    });
    if (!ok || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset token for ${user.email}'),
        content: SelectableText(token ?? ''),
        actions: [
          TextButton(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: token ?? '')),
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editPermissions(UserInfo user, List<String> all) async {
    final chosen = {...user.permissions};
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(user.email),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final code in all)
                CheckboxListTile(
                  title: Text(code),
                  value: chosen.contains(code),
                  // The base "user" grant is always kept by the server.
                  onChanged: code == 'user'
                      ? null
                      : (v) => setLocal(
                          () => v == true
                              ? chosen.add(code)
                              : chosen.remove(code),
                        ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true)
      await _call('PUT', '/manage/users/${user.id}/permissions', {
        'codes': chosen.toList(),
      });
  }

  Future<void> _newInvite() async {
    final uses = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New invitation code'),
        content: TextField(
          controller: uses,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Max uses',
            helperText: 'Leave empty for unlimited',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final maxUses = int.tryParse(uses.text.trim()); // empty = unlimited
    uses.dispose();
    if (ok == true)
      await _call('POST', '/manage/invites', {'max_uses': maxUses});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        final data = snap.data;
        if (data == null)
          return const Center(child: CircularProgressIndicator());
        final company = data.company;
        return ListView(
          children: [
            const ListTile(title: Text('Signup')),
            SwitchListTile(
              title: const Text('Company-email signup'),
              subtitle: Text(
                company['email_configured'] == true
                    ? 'Domain: ${company['allowed_domain']}'
                    : 'Needs email to be configured by the superuser',
              ),
              value: company['signup_domain_enabled'] as bool,
              onChanged: (v) => _call('PATCH', '/manage/company', {
                'signup_domain_enabled': v,
              }),
            ),
            SwitchListTile(
              title: const Text('Invitation-code signup'),
              value: company['signup_invite_enabled'] as bool,
              onChanged: (v) => _call('PATCH', '/manage/company', {
                'signup_invite_enabled': v,
              }),
            ),
            ListTile(
              title: const Text('Invitation codes'),
              subtitle: data.invites.isEmpty
                  ? const Text('No codes yet')
                  : null,
              trailing: FilledButton.icon(
                onPressed: _newInvite,
                icon: const Icon(Icons.add),
                label: const Text('New code'),
              ),
            ),
            for (final i in data.invites)
              ListTile(
                title: SelectableText('${i['code']}'),
                subtitle: Text('${i['uses']}/${i['max_uses'] ?? '∞'} used'),
                trailing: i['active'] == true
                    ? TextButton(
                        onPressed: () => _call(
                          'POST',
                          '/manage/invites/${i['id']}/deactivate',
                        ),
                        child: const Text('Deactivate'),
                      )
                    : const Text('inactive'),
              ),
            const ListTile(title: Text('People')),
            for (final u in data.users)
              ListTile(
                title: Text(
                  u.fullName.isEmpty ? u.email : '${u.fullName} · ${u.email}',
                ),
                subtitle: Text(
                  u.isActive ? u.permissions.join(', ') : 'deactivated',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => switch (action) {
                    'perms' => _editPermissions(u, data.permissionCodes),
                    'active' => _call('POST', '/manage/users/${u.id}/active', {
                      'active': !u.isActive,
                    }),
                    _ => _resetToken(u),
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'perms',
                      child: Text('Permissions'),
                    ),
                    PopupMenuItem(
                      value: 'active',
                      child: Text(u.isActive ? 'Deactivate' : 'Reactivate'),
                    ),
                    const PopupMenuItem(
                      value: 'reset',
                      child: Text('Issue reset token'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminData {
  const _AdminData({
    required this.users,
    required this.permissionCodes,
    required this.company,
    required this.invites,
  });
  final List<UserInfo> users;
  final List<String> permissionCodes;
  final Map<String, dynamic> company;
  final List<Map<String, dynamic>> invites;
}
