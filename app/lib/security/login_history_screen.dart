import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/security/security_models.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Successful and failed sign-ins, newest first. [load] is the caller's own history or, for a
/// manager, one user's.
class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({super.key, required this.load, this.subtitle});
  final Future<List<LoginEvent>> Function() load;
  final String? subtitle;

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  late Future<List<LoginEvent>> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.secLoginHistory)),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: l.secLoadFailed,
              message: '${snap.error}',
              action: OutlinedButton(
                onPressed: _reload,
                child: Text(l.commonRetry),
              ),
            );
          }
          final rows = snap.data;
          if (rows == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (rows.isEmpty) {
            return EmptyState(icon: Icons.history, title: l.secHistoryEmpty);
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                PageBody(
                  child: Column(
                    children: [
                      if (widget.subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(widget.subtitle!),
                        ),
                      for (final e in rows) LoginEventTile(event: e),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String loginReasonLabel(AppLocalizations l, String reason) => switch (reason) {
  'bad_password' => l.secReasonBadPassword,
  'bad_code' => l.secReasonBadCode,
  'locked' => l.secReasonLocked,
  'guest_expired' => l.secReasonGuestExpired,
  '' => '',
  _ => reason,
};

class LoginEventTile extends StatelessWidget {
  const LoginEventTile({super.key, required this.event});
  final LoginEvent event;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final details = [
      if (event.ip.isNotEmpty) event.ip,
      if (event.device.isNotEmpty) event.device,
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              event.success ? Icons.check_circle_outline : Icons.error_outline,
              color: event.success ? Tokens.ok : Tokens.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.success
                        ? l.secLoginOk
                        : '${l.secLoginFailed}: ${loginReasonLabel(l, event.reason)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    formatJalaliDateTime(event.at),
                    style: TextStyle(color: muted, fontSize: 12.5),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: muted, fontSize: 12.5),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
