import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';

/// Notices above the app shell: a guest's expiry date, and the company's "set up two-step
/// login" requirement. Collapses to nothing when there is nothing to say.
class AccountBanner extends StatelessWidget {
  const AccountBanner({super.key, required this.user});
  final UserInfo user;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final notes = <String>[];
    if (user.isGuest) {
      final end = user.guestExpiresAt;
      notes.add(
        end == null
            ? l.secGuestNotice
            : l.secGuestNoticeUntil(formatJalaliDate(end)),
      );
    }
    if (user.twoFactorSetupRequired) notes.add(l.secSetupRequiredNotice);
    if (notes.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notes.join(' '),
                  key: const ValueKey('account-banner'),
                  style: TextStyle(
                    color: scheme.onSecondaryContainer,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
