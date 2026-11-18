import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/keys/key_vault.dart';
import 'package:letter_signing/letters/letter_crypto_service.dart';
import 'package:letter_signing/letters/letters_api.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/notifications_screen.dart';
import 'package:letter_signing/letters/rewrap_service.dart';
import 'package:letter_signing/letters/sign_payload.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Everything the letter screens need, built once by the integrator after login.
class LettersEnv {
  LettersEnv({
    required this.api,
    required this.vault,
    required this.companyKeys,
    required this.live,
    required this.userId,
    this.canCreate = true,
    this.isManager = false,
    this.deviceName = '',
    this._sessionId,
  }) : crypto = LetterCryptoService(
         api: api,
         companyKeys: companyKeys,
         userId: userId,
       ),
       notifications = NotificationsController(api: api, live: live) {
    rewrap = RewrapService(api: api, crypto: crypto);
  }

  final LettersApi api;
  final KeyVault vault;
  final CompanyKeys companyKeys;
  final LiveService live;
  final int userId;
  final bool canCreate;
  final bool isManager;
  final String deviceName;
  final LetterCryptoService crypto;
  final NotificationsController notifications;
  late final RewrapService rewrap;
  final String? Function()? _sessionId;

  /// Login `session_id` if the integrator supplied it, else read from the access token.
  String? get sessionId =>
      _sessionId?.call() ?? sessionIdFromAccessToken(api.client.accessToken);
}

/// Shows a failure as a SnackBar (server messages are user-readable).
void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
}

String statusLabel(String status) => switch (status) {
  'draft' => 'Draft',
  'in_signing' => 'In signing',
  'published' => 'Published',
  'rejected' => 'Rejected',
  'cancelled' => 'Cancelled',
  _ => status,
};

Tone statusTone(String status) => switch (status) {
  'published' => Tone.ok,
  'rejected' => Tone.error,
  'in_signing' => Tone.warn,
  'draft' => Tone.info,
  _ => Tone.neutral,
};

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) =>
      StatusPill(statusLabel(status), tone: statusTone(status));
}
