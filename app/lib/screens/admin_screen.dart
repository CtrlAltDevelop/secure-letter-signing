import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/l10n/tr.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/screens/departments_card.dart';
import 'package:letter_signing/screens/letterhead_card.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/screens/auth_screens.dart';
import 'package:letter_signing/security/guests_card.dart';
import 'package:letter_signing/security/login_history_screen.dart';
import 'package:letter_signing/security/security_api.dart';
import 'package:letter_signing/security/user_access_screen.dart';
import 'package:letter_signing/workspace/workspace_api.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Manager-only: people & permissions, signup switches, invitation codes.
class AdminTab extends StatefulWidget {
  const AdminTab({super.key, required this.auth});
  final AuthController auth;

  @override
  State<AdminTab> createState() => _AdminTabState();
}

class _AdminTabState extends State<AdminTab> {
  late Future<_AdminData> _data = _load();
  late final SecurityApi _security = SecurityApi(WorkspaceApi(widget.auth.api));

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
        title: Text(tr.adminResetTokenTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.adminResetTokenBody(user.email)),
            const SizedBox(height: 12),
            SelectableText(
              token ?? '',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _copy(token ?? '', tr.adminTokenCopied),
            icon: const Icon(Icons.copy, size: 18),
            label: Text(tr.commonCopy),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr.commonClose),
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
          title: Text(tr.adminPermissions),
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
                        ? Text(tr.adminAlwaysGranted)
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
              child: Text(tr.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr.commonSave),
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

  void _openAccess(UserInfo user) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => UserAccessScreen(
        api: _security,
        userId: user.id,
        userName: user.fullName.isEmpty ? user.email : user.fullName,
        isGuest: user.isGuest,
      ),
    ),
  );

  void _openHistory(UserInfo user) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LoginHistoryScreen(
        load: () => _security.userLoginHistory(user.id),
        subtitle: user.email,
      ),
    ),
  );

  Future<void> _setDepartment(UserInfo user) async {
    if (await pickDepartment(context, widget.auth.api, user) && mounted) {
      _reload();
    }
  }

  Future<void> _newInvite(List<String> permissionCodes) async {
    final uses = TextEditingController(text: '1');
    final chosen = <String>{};
    int? department;
    var departments = <Map<String, dynamic>>[];
    try {
      departments = [
        for (final d
            in await widget.auth.api.call('GET', '/manage/departments') as List)
          if ((d as Map)['active'] == true) Map<String, dynamic>.from(d),
      ];
    } on Object catch (_) {
      // The code can still be created without a department.
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          icon: const Icon(Icons.confirmation_number_outlined),
          title: Text(tr.adminNewInviteTitle),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: uses,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: tr.adminMaxUses,
                      helperText: tr.adminUnlimitedHelper,
                      prefixIcon: const Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: department,
                    decoration: InputDecoration(
                      labelText: tr.adminDepartment,
                      prefixIcon: const Icon(Icons.apartment_outlined),
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(tr.adminNone),
                      ),
                      for (final d in departments)
                        DropdownMenuItem<int?>(
                          value: d['id'] as int,
                          child: Text('${d['name']}'),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => department = v),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr.adminInvitePermsHeader,
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  for (final code in permissionCodes)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(permissionLabel(code)),
                      subtitle: code == 'user'
                          ? Text(tr.adminAlwaysGranted)
                          : null,
                      value: code == 'user' || chosen.contains(code),
                      onChanged: code == 'user'
                          ? null
                          : (v) => setLocal(() {
                              if (v == true) {
                                chosen.add(code);
                              } else {
                                chosen.remove(code);
                              }
                            }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr.commonCreate),
            ),
          ],
        ),
      ),
    );
    final maxUses = int.tryParse(uses.text.trim()); // empty = unlimited
    uses.dispose();
    if (ok == true) {
      await _call('POST', '/manage/invites', {
        'max_uses': maxUses,
        'codes': chosen.toList(),
        'department_id': department,
      });
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
            title: tr.adminLoadFailed,
            message: '${snap.error}',
            action: OutlinedButton(
              onPressed: _reload,
              child: Text(tr.commonRetry),
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
                    ..._invitesSection(data.invites, data.permissionCodes),
                    GuestsCard(api: _security),
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
    SectionHeader(tr.adminSignupSection, subtitle: tr.adminSignupSubtitle),
    AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(tr.adminDomainSignup),
            subtitle: Text(
              company['email_configured'] == true
                  ? tr.adminDomainLabel('${company['allowed_domain']}')
                  : tr.adminNeedsEmail,
            ),
            value: company['signup_domain_enabled'] as bool,
            onChanged: (v) =>
                _call('PATCH', '/manage/company', {'signup_domain_enabled': v}),
          ),
          const Divider(indent: 16, endIndent: 16),
          SwitchListTile(
            title: Text(tr.adminInviteSignup),
            value: company['signup_invite_enabled'] as bool,
            onChanged: (v) =>
                _call('PATCH', '/manage/company', {'signup_invite_enabled': v}),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _invitesSection(
    List<Map<String, dynamic>> invites,
    List<String> permissionCodes,
  ) => [
    SectionHeader(
      tr.adminInvitesSection,
      trailing: FilledButton.tonalIcon(
        onPressed: () => _newInvite(permissionCodes),
        icon: const Icon(Icons.add),
        label: Text(tr.adminNewCode),
      ),
    ),
    if (invites.isEmpty)
      AppCard(child: Text(tr.adminNoCodes))
    else
      for (final i in invites) ...[
        _InviteCard(
          invite: i,
          onCopy: () => _copy('${i['code']}', tr.adminCodeCopied),
          onDeactivate: () =>
              _call('POST', '/manage/invites/${i['id']}/deactivate'),
        ),
        const SizedBox(height: 8),
      ],
  ];

  List<Widget> _peopleSection(_AdminData data) => [
    SectionHeader(tr.adminPeopleSection),
    for (final u in data.users) ...[
      _PersonCard(
        user: u,
        onSelected: (action) => switch (action) {
          'perms' => _editPermissions(u, data.permissionCodes),
          'dept' => _setDepartment(u),
          'access' => _openAccess(u),
          'history' => _openHistory(u),
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
                  tr.adminInviteUses(
                        '${invite['uses']}',
                        '${invite['max_uses'] ?? '\u221e'}',
                      ) +
                      (invite['guest'] == true
                          ? ' · ${AppLocalizations.of(context).secGuest}'
                          : ''),
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                if ((invite['codes'] as List?)?.isNotEmpty == true ||
                    '${invite['department'] ?? ''}'.isNotEmpty)
                  Text(
                    [
                      ...List<String>.from(invite['codes'] as List)
                          .map(permissionLabel),
                      if ('${invite['department']}'.isNotEmpty)
                        '${invite['department']}',
                    ].join(', '),
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr.adminCopyCode,
            icon: const Icon(Icons.copy),
            onPressed: onCopy,
          ),
          if (active)
            TextButton(onPressed: onDeactivate, child: Text(tr.adminDeactivate))
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: StatusPill(tr.adminInactive),
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
                      StatusPill(tr.profileManager, tone: Tone.info),
                    if (user.isGuest)
                      StatusPill(
                        AppLocalizations.of(context).secGuest,
                        tone: Tone.warn,
                      ),
                    if (user.department.isNotEmpty) StatusPill(user.department),
                    if (!user.isActive)
                      StatusPill(tr.adminDeactivated, tone: Tone.error)
                    else
                      for (final p in user.permissions)
                        StatusPill(permissionLabel(p)),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: tr.adminActions,
            onSelected: onSelected,
            itemBuilder: (_) => [
              PopupMenuItem(value: 'perms', child: Text(tr.adminPermissions)),
              PopupMenuItem(value: 'dept', child: Text(tr.adminDepartment)),
              PopupMenuItem(
                value: 'access',
                child: Text(AppLocalizations.of(context).secAccess),
              ),
              PopupMenuItem(
                value: 'history',
                child: Text(AppLocalizations.of(context).secLoginHistory),
              ),
              PopupMenuItem(
                value: 'active',
                child: Text(
                  user.isActive ? tr.adminDeactivate : tr.adminReactivate,
                ),
              ),
              PopupMenuItem(
                value: 'reset',
                child: Text(tr.adminIssueResetToken),
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
