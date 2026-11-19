import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/prefs/notification_history_screen.dart';
import 'package:letter_signing/prefs/personal_email_card.dart';
import 'package:letter_signing/prefs/prefs_controller.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/open_target.dart';
import 'package:letter_signing/workspace/widgets/jalali_date_field.dart';

/// How long the do-not-disturb presets last.
const dndPresets = [
  Duration(hours: 1),
  Duration(hours: 4),
  Duration(hours: 12),
];

/// More > Settings: theme, background image, status and birthday, personal email,
/// do-not-disturb and the notification history.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.userTitle,
    required this.open,
    this.embedded = false,
    this.now,
  });

  final PrefsController controller;

  /// The user's company title, shown under the status field.
  final String userTitle;
  final OpenFn open;
  final bool embedded;

  /// Clock for tests.
  final DateTime Function()? now;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PrefsController get c => widget.controller;
  late final _status = TextEditingController(text: c.statusText);
  bool _statusSeeded = false;

  @override
  void initState() {
    super.initState();
    if (!c.loaded) unawaited(c.load());
  }

  @override
  void dispose() {
    _status.dispose();
    super.dispose();
  }

  void _report(bool ok) {
    if (ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).prefsFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final body = ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!_statusSeeded && c.loaded) {
          _status.text = c.statusText;
          _statusSeeded = true;
        }
        return PageBody(
          child: ListView(
            children: [
              _theme(l),
              _background(l),
              _profile(context, l),
              PersonalEmailCard(controller: c),
              _dnd(l),
              const SizedBox(height: 8),
              ListTile(
                key: const ValueKey('open-notifications'),
                leading: const Icon(Icons.notifications_outlined),
                title: Text(l.notificationsTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NotificationHistoryScreen(
                        api: c.api,
                        open: widget.open,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: body,
    );
  }

  Widget _theme(AppLocalizations l) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.settingsTheme, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          key: const ValueKey('theme-select'),
          segments: [
            ButtonSegment(value: 'light', label: Text(l.settingsThemeLight)),
            ButtonSegment(value: 'dark', label: Text(l.settingsThemeDark)),
            ButtonSegment(value: 'auto', label: Text(l.settingsThemeAuto)),
          ],
          selected: {c.prefs.theme},
          onSelectionChanged: (s) =>
              unawaited(c.setTheme(s.first).then(_report)),
        ),
      ],
    ),
  );

  Widget _background(AppLocalizations l) => AppCard(
    child: Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceContainer,
            image: c.background == null
                ? null
                : DecorationImage(
                    image: MemoryImage(c.background!),
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(l.settingsBackground)),
        TextButton(
          key: const ValueKey('bg-choose'),
          onPressed: () => unawaited(c.chooseBackground().then(_report)),
          child: Text(l.settingsBackgroundChoose),
        ),
        if (c.prefs.hasBackground)
          IconButton(
            key: const ValueKey('bg-remove'),
            tooltip: l.settingsBackgroundRemove,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => unawaited(c.removeBackground().then(_report)),
          ),
      ],
    ),
  );

  Widget _profile(BuildContext context, AppLocalizations l) {
    final today = (widget.now ?? DateTime.now)();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.userTitle.isNotEmpty)
            Text(
              '${l.settingsTitleLabel}: ${widget.userTitle}',
              key: const ValueKey('settings-title'),
            ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('status-field'),
            controller: _status,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: l.settingsStatus,
              suffixIcon: IconButton(
                key: const ValueKey('status-save'),
                tooltip: l.commonSave,
                icon: const Icon(Icons.check),
                onPressed: () => unawaited(
                  c.saveProfile(statusText: _status.text.trim()).then(_report),
                ),
              ),
            ),
          ),
          JalaliDateField(
            key: const ValueKey('birthday-field'),
            label: l.settingsBirthday,
            value: c.prefs.birthday,
            lastDate: today,
            onChanged: (d) => unawaited(c.setBirthday(d).then(_report)),
          ),
          SwitchListTile(
            key: const ValueKey('birthday-visible'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.settingsBirthdayVisible),
            value: c.prefs.birthdayVisible,
            onChanged: (v) =>
                unawaited(c.setBirthdayVisible(visible: v).then(_report)),
          ),
        ],
      ),
    );
  }

  Widget _dnd(AppLocalizations l) {
    final now = (widget.now ?? DateTime.now)();
    final active = c.prefs.dndActive(now);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.settingsDnd, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            active
                ? l.settingsDndUntil(formatJalaliDateTime(c.prefs.dndUntil!))
                : l.settingsDndOff,
            key: const ValueKey('dnd-state'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final d in dndPresets)
                ActionChip(
                  key: ValueKey('dnd-${d.inHours}'),
                  label: Text(l.settingsDndHours(toPersianDigits(d.inHours))),
                  onPressed: () =>
                      unawaited(c.setDnd(now.add(d)).then(_report)),
                ),
              if (active)
                ActionChip(
                  key: const ValueKey('dnd-off'),
                  label: Text(l.settingsDndTurnOff),
                  onPressed: () => unawaited(c.setDnd(null).then(_report)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
