import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/bookmarks/bookmarks_screen.dart';
import 'package:letter_signing/bookmarks/pinned_screen.dart';
import 'package:letter_signing/calendar/calendar_screen.dart';
import 'package:letter_signing/letters/letters_admin_screen.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/notifications_screen.dart';
import 'package:letter_signing/letters/sign_approval_host.dart';
import 'package:letter_signing/prefs/settings_screen.dart';
import 'package:letter_signing/screens/admin_screen.dart';
import 'package:letter_signing/search/search_screen.dart';
import 'package:letter_signing/screens/biometric_enrol.dart';
import 'package:letter_signing/screens/profile_tab.dart';
import 'package:letter_signing/screens/sessions_tab.dart';
import 'package:letter_signing/screens/signing_pin.dart';
import 'package:letter_signing/security/account_banner.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/labels_screen.dart';
import 'package:letter_signing/monitor/monitor_screen.dart';
import 'package:letter_signing/monitor/my_numbers_card.dart';
import 'package:letter_signing/workspace/module_registry.dart';
import 'package:letter_signing/workspace/workspace_env.dart';

const _wideBreakpoint = 900.0;

/// Module destinations that fill the phone bottom bar; everything else goes under "More".
const _maxPrimaryModules = 3;

/// Destinations a guest never sees (everything that is not a module, profile, devices or settings).
const _guestHidden = {
  'numbers',
  'monitor',
  'calendar',
  'pinned',
  'bookmarks',
  'labels',
  'all_letters',
  'admin',
};

/// Module opened first.
const _defaultModule = 'tasks';

class _Dest {
  const _Dest(this.key, this.label, this.icon, this.selectedIcon, this.page);
  final String key;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() page;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.auth, this.live});
  final AuthController auth;

  /// Replaces the real socket-backed stream (tests).
  final LiveService? live;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final WorkspaceEnv _env = WorkspaceEnv.forAuth(
    widget.auth,
    // Not Theme.of(context): this runs in initState.
    deviceName: kIsWeb ? 'web' : defaultTargetPlatform.name,
    live: widget.live,
  );
  String _selected = _defaultModule;
  final _visited = <String>{_defaultModule};
  final _pages = <String, Widget>{};

  @override
  void initState() {
    super.initState();
    _env.live.start();
    unawaited(_env.loadModules());
    unawaited(_env.prefs.load());
  }

  @override
  void dispose() {
    unawaited(_env.disposeAll());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    if (user == null) return const SizedBox.shrink();
    // The signing PIN is part of signing up: nobody enters the app without one.
    if (!user.hasSigningPin) return SigningPinGate(auth: widget.auth);
    return BiometricEnrolPrompt(
      auth: widget.auth,
      child: SignApprovalHost(
        env: _env.letters,
        child: ListenableBuilder(
          listenable: _env,
          builder: (context, _) => _shell(user),
        ),
      ),
    );
  }

  /// Enabled modules first (they fill the phone bottom bar), then profile, devices, manager items.
  List<_Dest> _destinations(UserInfo user, AppLocalizations l) {
    final all = _allDestinations(user, l);
    // A guest sees only the modules the server returns plus the personal pages.
    if (!user.isGuest) return all;
    return [
      for (final d in all)
        if (!_guestHidden.contains(d.key)) d,
    ];
  }

  List<_Dest> _allDestinations(UserInfo user, AppLocalizations l) {
    final auth = widget.auth;
    return [
      for (final m in enabledModules(_env))
        _Dest(m.code, m.label(l), m.icon, m.selectedIcon, () => m.build(_env)),
      _Dest(
        'numbers',
        l.monMyNumbers,
        Icons.speed_outlined,
        Icons.speed,
        () => MyNumbersScreen(env: _env.monitor),
      ),
      if (_env.monitor.canMonitor)
        _Dest(
          'monitor',
          l.monTitle,
          Icons.monitor_heart_outlined,
          Icons.monitor_heart,
          () => MonitorScreen(env: _env.monitor, embedded: true),
        ),
      _Dest(
        'calendar',
        l.calendarTitle,
        Icons.calendar_month_outlined,
        Icons.calendar_month,
        () => CalendarScreen(env: _env.calendar, embedded: true),
      ),
      _Dest(
        'pinned',
        l.pinnedTitle,
        Icons.push_pin_outlined,
        Icons.push_pin,
        () => PinnedScreen(api: _env.bookmarks, open: _env.open),
      ),
      _Dest(
        'bookmarks',
        l.bookmarksTitle,
        Icons.bookmark_border,
        Icons.bookmark,
        () => BookmarksScreen(
          api: _env.bookmarks,
          open: _env.open,
          embedded: true,
        ),
      ),
      _Dest(
        'settings',
        l.settingsTitle,
        Icons.settings_outlined,
        Icons.settings,
        () => SettingsScreen(
          controller: _env.prefs,
          userTitle: user.title,
          open: _env.open,
          embedded: true,
        ),
      ),
      _Dest(
        'profile',
        l.navProfile,
        Icons.person_outline,
        Icons.person,
        () => ProfileTab(auth: auth),
      ),
      _Dest(
        'labels',
        l.navLabels,
        Icons.label_outline,
        Icons.label,
        () => LabelsScreen(
          api: _env.tasks.api.workspace,
          isManager: user.isManager,
          onChanged: _env.tasks.invalidateLabels,
        ),
      ),
      _Dest(
        'devices',
        l.navDevices,
        Icons.devices_other_outlined,
        Icons.devices_other,
        () => SessionsTab(auth: auth),
      ),
      if (user.isManager) ...[
        _Dest(
          'all_letters',
          l.navAllLetters,
          Icons.inventory_2_outlined,
          Icons.inventory_2,
          () => LettersAdminScreen(env: _env.letters, embedded: true),
        ),
        _Dest(
          'admin',
          l.navAdmin,
          Icons.admin_panel_settings_outlined,
          Icons.admin_panel_settings,
          () => AdminTab(auth: auth),
        ),
      ],
    ];
  }

  /// Index of the selected destination; falls back to the first when it vanished
  /// (e.g. its module got disabled).
  int _indexOf(List<_Dest> dests) {
    final i = dests.indexWhere((d) => d.key == _selected);
    return i < 0 ? 0 : i;
  }

  void _select(String key) {
    setState(() {
      _selected = key;
      _visited.add(key);
    });
  }

  Widget _body(List<_Dest> dests, int index) => IndexedStack(
    index: index,
    children: [
      for (final d in dests)
        if (_visited.contains(d.key))
          _pages.putIfAbsent(d.key, d.page)
        else
          const SizedBox.shrink(),
    ],
  );

  /// Guest-expiry / "set up two-step login" notices above the page.
  Widget _withBanner(UserInfo user, Widget body) => Column(
    children: [
      AccountBanner(user: user),
      Expanded(child: body),
    ],
  );

  Widget _shell(UserInfo user) {
    final l = AppLocalizations.of(context);
    final dests = _destinations(user, l);
    final index = _indexOf(dests);
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final appBar = AppBar(
      title: Text(dests[index].label),
      actions: [
        if (!user.isGuest)
          IconButton(
            key: const ValueKey('open-search'),
            tooltip: l.searchTitle,
            icon: const Icon(Icons.search),
            onPressed: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      SearchScreen(api: _env.searchApi, open: _env.open),
                ),
              ),
            ),
          ),
        NotificationBell(env: _env.letters),
        if (!wide)
          IconButton(
            tooltip: l.signOut,
            icon: const Icon(Icons.logout),
            onPressed: widget.auth.logout,
          ),
      ],
    );
    if (!wide) {
      return Scaffold(
        appBar: appBar,
        body: _withBanner(user, _body(dests, index)),
        bottomNavigationBar: _bottomBar(dests, index, l),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          _rail(dests, index, user, l),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _withBanner(user, _body(dests, index))),
        ],
      ),
    );
  }

  /// How many destinations are module tabs on the bottom bar.
  int _primaryCount(List<_Dest> dests) =>
      enabledModules(_env).length
          .clamp(0, _maxPrimaryModules)
          .clamp(0, dests.length);

  Widget _bottomBar(List<_Dest> dests, int index, AppLocalizations l) {
    final count = _primaryCount(dests);
    final inMore = index >= count;
    return NavigationBar(
      selectedIndex: inMore ? count : index,
      onDestinationSelected: (i) {
        if (i < count) {
          _select(dests[i].key);
        } else {
          unawaited(_openMore(dests, count));
        }
      },
      destinations: [
        for (final d in dests.take(count))
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
        NavigationDestination(
          icon: const Icon(Icons.more_horiz),
          selectedIcon: const Icon(Icons.more_horiz),
          label: l.navMore,
        ),
      ],
    );
  }

  Future<void> _openMore(List<_Dest> dests, int count) async {
    final selected = dests[_indexOf(dests)].key;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in dests.skip(count))
                ListTile(
                  leading: Icon(d.key == selected ? d.selectedIcon : d.icon),
                  title: Text(d.label),
                  selected: d.key == selected,
                  onTap: () => Navigator.pop(ctx, d.key),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) _select(picked);
  }

  Widget _rail(
    List<_Dest> dests,
    int index,
    UserInfo user,
    AppLocalizations l,
  ) {
    // Scrolls when there are more destinations than the window is tall.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              extended: true,
              minExtendedWidth: 220,
              selectedIndex: index,
              onDestinationSelected: (i) => _select(dests[i].key),
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: BrandLogo(size: 48),
              ),
              trailing: Expanded(child: _railUser(user, l)),
              destinations: [
                for (final d in dests)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _railUser(UserInfo user, AppLocalizations l) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Align(
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
                tooltip: l.signOut,
                icon: const Icon(Icons.logout),
                onPressed: widget.auth.logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
