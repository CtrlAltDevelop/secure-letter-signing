import 'package:flutter/material.dart';

import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/screens/admin_screen.dart';
import 'package:letter_signing/screens/auth_screens.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final tabs = <(String, Widget)>[
      ('Profile', ProfileTab(auth: auth)),
      ('Devices', SessionsTab(auth: auth)),
      if (user.isManager) ('Admin', AdminTab(auth: auth)),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(user.fullName.isEmpty ? user.email : user.fullName),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: auth.logout,
            ),
          ],
          bottom: TabBar(tabs: [for (final t in tabs) Tab(text: t.$1)]),
        ),
        body: TabBarView(children: [for (final t in tabs) t.$2]),
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final _name = TextEditingController(text: widget.auth.user?.fullName);
  late final _title = TextEditingController(text: widget.auth.user?.title);
  late final _department = TextEditingController(
    text: widget.auth.user?.department,
  );
  final _current = TextEditingController();
  final _next = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _title, _department, _current, _next]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final ok = await runGuarded(
      context,
      () => widget.auth.updateProfile(
        fullName: _name.text,
        title: _title.text,
        department: _department.text,
      ),
    );
    if (ok && mounted) _toast('Saved');
  }

  Future<void> _changePassword() async {
    final ok = await runGuarded(
      context,
      () => widget.auth.changePassword(_current.text, _next.text),
    );
    if (!ok || !mounted) return;
    _current.clear();
    _next.clear();
    _toast('Password changed; other devices were signed out');
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(user?.email ?? '', style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: 8,
          children: [
            for (final p in user?.permissions ?? const <String>[])
              Chip(label: Text(p)),
          ],
        ),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Job title'),
        ),
        TextField(
          controller: _department,
          decoration: const InputDecoration(labelText: 'Department'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            onPressed: _saveProfile,
            child: const Text('Save'),
          ),
        ),
        const Divider(height: 32),
        TextField(
          controller: _current,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        TextField(
          controller: _next,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton(
            onPressed: _changePassword,
            child: const Text('Change password'),
          ),
        ),
      ],
    );
  }
}

class SessionsTab extends StatefulWidget {
  const SessionsTab({super.key, required this.auth});
  final AuthController auth;

  @override
  State<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  late Future<List<Map<String, dynamic>>> _sessions = _load();

  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(
        await widget.auth.api.call('GET', '/me/sessions') as List,
      );

  Future<void> _revoke(String id) async {
    final ok = await runGuarded(
      context,
      () => widget.auth.api.call('POST', '/me/sessions/$id/revoke'),
    );
    if (ok && mounted) setState(() => _sessions = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _sessions,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        final rows = snap.data;
        if (rows == null)
          return const Center(child: CircularProgressIndicator());
        return ListView(
          children: [
            for (final s in rows)
              ListTile(
                leading: const Icon(Icons.devices),
                title: Text(
                  '${s['device_name']}'.isEmpty
                      ? '${s['platform']}'
                      : '${s['device_name']}',
                ),
                subtitle: Text(
                  '${s['ip'] ?? ''}  ·  last active ${s['last_active']}',
                ),
                trailing: s['current'] == true
                    ? const Chip(label: Text('This device'))
                    : IconButton(
                        tooltip: 'Sign out this device',
                        icon: const Icon(Icons.close),
                        onPressed: () => _revoke(s['id'] as String),
                      ),
              ),
          ],
        );
      },
    );
  }
}
