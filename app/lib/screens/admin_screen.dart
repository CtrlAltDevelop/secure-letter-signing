import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/keys/company_key_service.dart';
import 'package:letter_signing/keys/key_vault.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/screens/company_key_card.dart';
import 'package:letter_signing/screens/departments_card.dart';
import 'package:letter_signing/screens/letterhead_card.dart';
import 'package:letter_signing/screens/auth_screens.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Manager-only: people & permissions, signup switches, invitation codes.
class AdminTab extends StatefulWidget {
  const AdminTab({
    super.key,
    required this.auth,
    required this.vault,
    required this.companyKeys,
  });
  final AuthController auth;
  final KeyVault vault;
  final CompanyKeyService companyKeys;

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
        icon: const Icon(Icons.key_outlined),
        title: const Text('Password reset token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Give this token to ${user.email}. It is shown only once.'),
            const SizedBox(height: 12),
            SelectableText(
              token ?? '',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _copy(token ?? '', 'Token copied'),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(String value, String done) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
  }

  Future<void> _editPermissions(UserInfo user, List<String> all) async {
    final chosen = {...user.permissions};
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Permissions'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.email,
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final code in all)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(permissionLabel(code)),
                    subtitle: code == 'user'
                        ? const Text('Always granted')
                        : Text(code),
                    value: chosen.contains(code),
                    // The base "user" grant is always kept by the server.
                    onChanged: code == 'user'
                        ? null
                        : (v) {
                            setLocal(() {
                              if (v == true) {
                                chosen.add(code);
                              } else {
                                chosen.remove(code);
                              }
                            });
                          },
                  ),
              ],
            ),
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
    if (saved == true) {
      await _call('PUT', '/manage/users/${user.id}/permissions', {
        'codes': chosen.toList(),
      });
    }
  }

  Future<void> _setDepartment(UserInfo user) async {
    if (await pickDepartment(context, widget.auth.api, user) && mounted) {
      _reload();
    }
  }

  Future<void> _newInvite() async {
    final uses = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.confirmation_number_outlined),
        title: const Text('New invitation code'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: uses,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Max uses',
              helperText: 'Leave empty for unlimited',
              prefixIcon: Icon(Icons.tag),
            ),
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
    if (ok == true) {
      await _call('POST', '/manage/invites', {'max_uses': maxUses});
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load admin data',
            message: '${snap.error}',
            action: OutlinedButton(
              onPressed: _reload,
              child: const Text('Retry'),
            ),
          );
        }
        final data = snap.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CompanyKeyCard(
                      api: widget.auth.api,
                      vault: widget.vault,
                      service: widget.companyKeys,
                    ),
                    LetterheadCard(
                      key: ValueKey(data.company['letterhead'].hashCode),
                      api: widget.auth.api,
                      initial: Letterhead.fromJson(
                        Map<String, dynamic>.from(
                          data.company['letterhead'] as Map? ?? const {},
                        ),
                      ),
                    ),
                    ..._signupSection(data.company),
                    DepartmentsCard(api: widget.auth.api, onChanged: _reload),
                    ..._invitesSection(data.invites),
                    ..._peopleSection(data),
                    const SizedBox(height: Tokens.gap),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _signupSection(Map<String, dynamic> company) => [
    const SectionHeader('Signup', subtitle: 'How new people can join'),
    AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Company-email signup'),
            subtitle: Text(
              company['email_configured'] == true
                  ? 'Domain: ${company['allowed_domain']}'
                  : 'Needs email to be configured by the superuser',
            ),
            value: company['signup_domain_enabled'] as bool,
            onChanged: (v) =>
                _call('PATCH', '/manage/company', {'signup_domain_enabled': v}),
          ),
          const Divider(indent: 16, endIndent: 16),
          SwitchListTile(
            title: const Text('Invitation-code signup'),
            value: company['signup_invite_enabled'] as bool,
            onChanged: (v) =>
                _call('PATCH', '/manage/company', {'signup_invite_enabled': v}),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _invitesSection(List<Map<String, dynamic>> invites) => [
    SectionHeader(
      'Invitation codes',
      trailing: FilledButton.tonalIcon(
        onPressed: _newInvite,
        icon: const Icon(Icons.add),
        label: const Text('New code'),
      ),
    ),
    if (invites.isEmpty)
      const AppCard(child: Text('No codes yet'))
    else
      for (final i in invites) ...[
        _InviteCard(
          invite: i,
          onCopy: () => _copy('${i['code']}', 'Code copied'),
          onDeactivate: () =>
              _call('POST', '/manage/invites/${i['id']}/deactivate'),
        ),
        const SizedBox(height: 8),
      ],
  ];

  List<Widget> _peopleSection(_AdminData data) => [
    const SectionHeader('People'),
    for (final u in data.users) ...[
      _PersonCard(
        user: u,
        onSelected: (action) => switch (action) {
          'perms' => _editPermissions(u, data.permissionCodes),
          'dept' => _setDepartment(u),
          'active' => _call('POST', '/manage/users/${u.id}/active', {
            'active': !u.isActive,
          }),
          _ => _resetToken(u),
        },
      ),
      const SizedBox(height: 8),
    ],
  ];
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.onCopy,
    required this.onDeactivate,
  });
  final Map<String, dynamic> invite;
  final VoidCallback onCopy;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final active = invite['active'] == true;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  '${invite['code']}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${invite['uses']}/${invite['max_uses'] ?? '\u221e'} used',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy code',
            icon: const Icon(Icons.copy),
            onPressed: onCopy,
          ),
          if (active)
            TextButton(onPressed: onDeactivate, child: const Text('Deactivate'))
          else
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: StatusPill('Inactive'),
            ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.user, required this.onSelected});
  final UserInfo user;
  final void Function(String action) onSelected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(fullName: user.fullName, email: user.email),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isEmpty ? user.email : user.fullName,
                  style: text.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.fullName.isNotEmpty)
                  Text(
                    user.email,
                    style: text.bodySmall?.copyWith(color: muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (user.isManager)
                      const StatusPill('Manager', tone: Tone.info),
                    if (user.department.isNotEmpty) StatusPill(user.department),
                    if (!user.isActive)
                      const StatusPill('Deactivated', tone: Tone.error)
                    else
                      for (final p in user.permissions)
                        StatusPill(permissionLabel(p)),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: onSelected,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'perms', child: Text('Permissions')),
              const PopupMenuItem(value: 'dept', child: Text('Department')),
              PopupMenuItem(
                value: 'active',
                child: Text(user.isActive ? 'Deactivate' : 'Reactivate'),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Text('Issue reset token'),
              ),
            ],
          ),
        ],
      ),
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
