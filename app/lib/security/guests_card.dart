import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/jalali/jalali_picker.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/security/login_history_screen.dart';
import 'package:letter_signing/security/security_api.dart';
import 'package:letter_signing/security/security_models.dart';
import 'package:letter_signing/security/user_access_screen.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Manager: guest accounts (create, set expiry, deactivate) and guest invitation codes.
class GuestsCard extends StatefulWidget {
  const GuestsCard({super.key, required this.api});
  final SecurityApi api;

  @override
  State<GuestsCard> createState() => _GuestsCardState();
}

class _GuestsCardState extends State<GuestsCard> {
  List<GuestUser>? _guests;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final g = await widget.api.guests();
      if (mounted) {
        setState(() {
          _guests = g;
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<DateTime?> _pickExpiry(DateTime? initial) => showJalaliDatePicker(
    context,
    initialDate: initial ?? DateTime.now().add(const Duration(days: 30)),
    firstDate: DateTime.now().add(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 3650)),
  );

  /// Expiry as the end of the chosen day (the server needs a future instant).
  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59);

  Future<void> _newGuest() async {
    final draft = await showDialog<_GuestDraft>(
      context: context,
      builder: (_) => const _GuestDialog(),
    );
    if (draft == null) return;
    await _run(
      () async => widget.api.createGuest(
        email: draft.email,
        password: draft.password,
        fullName: draft.name,
        expiresAt: draft.expiresAt,
      ),
    );
  }

  Future<void> _setExpiry(GuestUser g) async {
    final picked = await _pickExpiry(g.expiresAt);
    if (picked == null) return;
    await _run(
      () async => widget.api.updateGuest(g.id, expiresAt: _endOfDay(picked)),
    );
  }

  Future<void> _newInvite() async {
    final l = AppLocalizations.of(context);
    DateTime? expiry;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l.secGuestInvite),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.secGuestInviteHelp),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('invite-expiry'),
                icon: const Icon(Icons.event),
                label: Text(
                  expiry == null ? l.secNoExpiry : formatJalaliDate(expiry!),
                ),
                onPressed: () async {
                  final d = await _pickExpiry(expiry);
                  if (d != null) setLocal(() => expiry = _endOfDay(d));
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              key: const ValueKey('invite-create'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.secCreate),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    Map<String, dynamic>? invite;
    await _run(() async {
      invite = await widget.api.createGuestInvite(guestExpiresAt: expiry);
    });
    final code = invite?['code'];
    if (code == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.secGuestInviteCode),
        content: SelectableText(
          '$code',
          key: const ValueKey('invite-code'),
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: '$code')),
            child: Text(l.secCopy),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonConfirm),
          ),
        ],
      ),
    );
  }

  void _history(GuestUser g) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LoginHistoryScreen(
        load: () => widget.api.userLoginHistory(g.id),
        subtitle: g.email,
      ),
    ),
  );

  void _access(GuestUser g) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => UserAccessScreen(
        api: widget.api,
        userId: g.id,
        userName: g.fullName.isEmpty ? g.email : g.fullName,
        isGuest: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final guests = _guests;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          l.secGuests,
          subtitle: l.secGuestsHelp,
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                key: const ValueKey('guest-invite'),
                tooltip: l.secGuestInvite,
                icon: const Icon(Icons.confirmation_number_outlined),
                onPressed: _newInvite,
              ),
              IconButton(
                key: const ValueKey('guest-new'),
                tooltip: l.secGuestNew,
                icon: const Icon(Icons.person_add_alt),
                onPressed: _newGuest,
              ),
            ],
          ),
        ),
        if (guests == null)
          AppCard(
            child: _error != null
                ? Text(l.secLoadFailed)
                : const Center(child: CircularProgressIndicator()),
          )
        else if (guests.isEmpty)
          AppCard(child: Text(l.secGuestsEmpty))
        else
          for (final g in guests)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GuestTile(
                guest: g,
                onExpiry: () => _setExpiry(g),
                onClearExpiry: () => _run(
                  () async => widget.api.updateGuest(g.id, clearExpiry: true),
                ),
                onActive: () =>
                    _run(() => widget.api.setActive(g.id, active: !g.isActive)),
                onHistory: () => _history(g),
                onAccess: () => _access(g),
              ),
            ),
      ],
    );
  }
}

class _GuestTile extends StatelessWidget {
  const _GuestTile({
    required this.guest,
    required this.onExpiry,
    required this.onClearExpiry,
    required this.onActive,
    required this.onHistory,
    required this.onAccess,
  });
  final GuestUser guest;
  final VoidCallback onExpiry;
  final VoidCallback onClearExpiry;
  final VoidCallback onActive;
  final VoidCallback onHistory;
  final VoidCallback onAccess;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final expiry = guest.expiresAt;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guest.fullName.isEmpty ? guest.email : guest.fullName),
                if (guest.fullName.isNotEmpty)
                  Text(
                    guest.email,
                    style: TextStyle(color: muted, fontSize: 12.5),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    if (!guest.isActive)
                      StatusPill(l.secDeactivated, tone: Tone.error)
                    else if (guest.expired)
                      StatusPill(l.secExpired, tone: Tone.warn)
                    else
                      StatusPill(l.secActive, tone: Tone.ok),
                    StatusPill(
                      expiry == null
                          ? l.secNoExpiry
                          : l.secExpiresOn(formatJalaliDate(expiry)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            key: ValueKey('guest-menu-${guest.id}'),
            onSelected: (v) => switch (v) {
              'expiry' => onExpiry(),
              'clear' => onClearExpiry(),
              'active' => onActive(),
              'access' => onAccess(),
              _ => onHistory(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'expiry', child: Text(l.secSetExpiry)),
              if (expiry != null)
                PopupMenuItem(value: 'clear', child: Text(l.secClearExpiry)),
              PopupMenuItem(value: 'access', child: Text(l.secAccess)),
              PopupMenuItem(value: 'history', child: Text(l.secLoginHistory)),
              PopupMenuItem(
                value: 'active',
                child: Text(guest.isActive ? l.secDeactivate : l.secReactivate),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuestDraft {
  const _GuestDraft(this.email, this.name, this.password, this.expiresAt);
  final String email;
  final String name;
  final String password;
  final DateTime? expiresAt;
}

class _GuestDialog extends StatefulWidget {
  const _GuestDialog();

  @override
  State<_GuestDialog> createState() => _GuestDialogState();
}

class _GuestDialogState extends State<_GuestDialog> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  DateTime? _expiry;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _name, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final l = AppLocalizations.of(context);
    if (!_email.text.contains('@') || _password.text.length < 8) {
      setState(() => _error = l.secGuestInvalid);
      return;
    }
    Navigator.pop(
      context,
      _GuestDraft(
        _email.text.trim(),
        _name.text.trim(),
        _password.text,
        _expiry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.secGuestNew),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('guest-email'),
                controller: _email,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l.secEmail),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('guest-name'),
                controller: _name,
                decoration: InputDecoration(labelText: l.secFullName),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('guest-password'),
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l.secPassword,
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('guest-expiry'),
                icon: const Icon(Icons.event),
                label: Text(
                  _expiry == null ? l.secNoExpiry : formatJalaliDate(_expiry!),
                ),
                onPressed: () async {
                  final d = await showJalaliDatePicker(
                    context,
                    initialDate:
                        _expiry ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (d == null) return;
                  setState(
                    () => _expiry = DateTime(d.year, d.month, d.day, 23, 59),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('guest-create'),
          onPressed: _submit,
          child: Text(l.secCreate),
        ),
      ],
    );
  }
}
