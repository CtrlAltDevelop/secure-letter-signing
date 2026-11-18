import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/screens/admin_screen.dart';
import 'package:letter_signing/keys/company_key_service.dart';
import 'package:letter_signing/keys/device_key_vault.dart';
import 'package:letter_signing/keys/key_approvals_screen.dart';
import 'package:letter_signing/keys/key_setup_screen.dart';
import 'package:letter_signing/keys/key_store.dart';
import 'package:letter_signing/keys/my_keys_screen.dart';
import 'package:letter_signing/letters/letters_admin_screen.dart';
import 'package:letter_signing/letters/letters_api.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/letters_list_screen.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/notifications_screen.dart';
import 'package:letter_signing/screens/profile_tab.dart';
import 'package:letter_signing/screens/sessions_tab.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/widgets.dart';

const _wideBreakpoint = 900.0;

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon, this.page);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() page;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _keyStore = KeyStore(userId: widget.auth.user!.id);
  late final _companyKeys = CompanyKeyService(widget.auth.api, _keyStore);
  late final LettersEnv _env = _buildEnv();
  late Future<StoredKey?> _localKey = _loadKey();
  int _index = 0;
  final _visited = <int>{0};
  final _pages = <int, Widget>{};

  /// This account's key on this device; adopts a key saved by an older build if the server says it is ours.
  Future<StoredKey?> _loadKey() async {
    final local = await _keyStore.load();
    if (local != null) return local;
    try {
      final mine = await widget.auth.api.call('GET', '/keys/mine') as List;
      final ids = {for (final k in mine) (k as Map)['id'] as String};
      if (await _keyStore.adoptDeviceKey(ids)) return await _keyStore.load();
    } on Exception {
      // Offline: the user can still create a key; an old key is adopted on a later launch.
    }
    return null;
  }

  LettersEnv _buildEnv() {
    final user = widget.auth.user!;
    final api = widget.auth.api;
    return LettersEnv(
      api: LettersApi(api),
      vault: DeviceKeyVault(api, _keyStore),
      companyKeys: _companyKeys,
      live: LiveService(api: api, cursor: SecureCursorStore(user.id)),
      userId: user.id,
      canCreate: user.permissions.contains('letter.create'),
      isManager: user.isManager,
      deviceName: defaultTargetPlatform
          .name, // not Theme.of(context): this runs in initState
      sessionId: () => widget.auth.sessionId,
    );
  }

  @override
  void initState() {
    super.initState();
    _env.live.start();
  }

  @override
  void dispose() {
    unawaited(_env.live.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    if (user == null) return const SizedBox.shrink();
    // A signing key is part of signing up: nobody enters the app on a device that has none.
    return FutureBuilder<StoredKey?>(
      future: _localKey,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == null) return _keyGate();
        return _shell(user);
      },
    );
  }

  Widget _keyGate() => KeySetupScreen(
    api: widget.auth.api,
    store: _keyStore,
    deviceName: defaultTargetPlatform.name,
    onSignOut: widget.auth.logout,
    onChanged: () {
      // Block body on purpose: an arrow would make setState's callback return the Future.
      setState(() {
        _localKey = _keyStore.load();
      });
    },
  );

  /// Primary destinations first (they fill the phone bottom bar), manager items after.
  List<_Dest> _destinations(UserInfo user) {
    final auth = widget.auth;
    return [
      _Dest(
        'Letters',
        Icons.mail_outline,
        Icons.mail,
        () => LettersListScreen(env: _env, embedded: true),
      ),
      _Dest(
        'Keys',
        Icons.vpn_key_outlined,
        Icons.vpn_key,
        () => MyKeysScreen(api: auth.api, store: _keyStore, embedded: true),
      ),
      _Dest(
        'Profile',
        Icons.person_outline,
        Icons.person,
        () => ProfileTab(auth: auth),
      ),
      _Dest(
        'Devices',
        Icons.devices_other_outlined,
        Icons.devices_other,
        () => SessionsTab(auth: auth),
      ),
      if (user.isManager) ...[
        _Dest(
          'Approvals',
          Icons.how_to_reg_outlined,
          Icons.how_to_reg,
          () => KeyApprovalsScreen(api: auth.api, embedded: true),
        ),
        _Dest(
          'All letters',
          Icons.inventory_2_outlined,
          Icons.inventory_2,
          () => LettersAdminScreen(env: _env, embedded: true),
        ),
        _Dest(
          'Admin',
          Icons.admin_panel_settings_outlined,
          Icons.admin_panel_settings,
          () => AdminTab(
            auth: auth,
            vault: _env.vault,
            companyKeys: _companyKeys,
          ),
        ),
      ],
    ];
  }

  void _select(int i) {
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  Widget _body(List<_Dest> dests) => IndexedStack(
    index: _index,
    children: [
      for (final (i, d) in dests.indexed)
        if (_visited.contains(i))
          _pages.putIfAbsent(i, d.page)
        else
          const SizedBox.shrink(),
    ],
  );

  Widget _shell(UserInfo user) {
    final dests = _destinations(user);
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final title = dests[_index].label;
    final appBar = AppBar(
      title: Text(title),
      actions: [
        NotificationBell(env: _env),
        if (!wide)
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: widget.auth.logout,
          ),
      ],
    );
    if (!wide) {
      return Scaffold(
        appBar: appBar,
        body: _body(dests),
        bottomNavigationBar: _bottomBar(dests, user),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          _rail(dests, user),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _body(dests)),
        ],
      ),
    );
  }

  static const _primaryCount = 4;

  Widget _bottomBar(List<_Dest> dests, UserInfo user) {
    final primary = dests.take(_primaryCount).toList();
    final inMore = _index >= _primaryCount;
    return NavigationBar(
      selectedIndex: inMore ? _primaryCount : _index,
      onDestinationSelected: (i) {
        if (i < _primaryCount) {
          _select(i);
        } else {
          unawaited(_openMore(dests));
        }
      },
      destinations: [
        for (final d in primary)
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
        if (user.isManager)
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
      ],
    );
  }

  Future<void> _openMore(List<_Dest> dests) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, d) in dests.indexed.skip(_primaryCount))
              ListTile(
                leading: Icon(i == _index ? d.selectedIcon : d.icon),
                title: Text(d.label),
                selected: i == _index,
                onTap: () => Navigator.pop(ctx, i),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) _select(picked);
  }

  Widget _rail(List<_Dest> dests, UserInfo user) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return NavigationRail(
      extended: true,
      minExtendedWidth: 220,
      selectedIndex: _index,
      onDestinationSelected: _select,
      leading: const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: BrandLogo(size: 48),
      ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: 196,
              child: Row(
                children: [
                  UserAvatar(
                    fullName: user.fullName,
                    email: user.email,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      user.fullName.isEmpty ? user.email : user.fullName,
                      style: text.bodyMedium?.copyWith(color: muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout),
                    onPressed: widget.auth.logout,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      destinations: [
        for (final d in dests)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
    );
  }
}
