import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/auth/biometrics.dart';
import 'package:letter_signing/letters/letter_service.dart';
import 'package:letter_signing/letters/letters_api.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/notifications_screen.dart';
import 'package:letter_signing/letters/sign_approvals.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Everything the letter screens need, built once by the integrator after login.
class LettersEnv {
  LettersEnv({
    required this.api,
    required this.live,
    required this.userId,
    this.biometrics = const LocalAuthBiometrics(),
    this.canCreate = true,
    this.isManager = false,
    this.deviceName = '',
    this.enrollBiometric,
    this._sessionId,
  }) : letters = LetterService(api: api, userId: userId),
       notifications = NotificationsController(api: api, live: live),
       approvals = SignApprovals(api: api, live: live, biometrics: biometrics);

  final LettersApi api;
  final LiveService live;
  final int userId;
  final Biometrics biometrics;

  /// Enrols this session's fingerprint/face with the PIN; null when unsupported.
  final Future<bool> Function(String pin)? enrollBiometric;
  final bool canCreate;
  final bool isManager;
  final String deviceName;
  final LetterService letters;
  final NotificationsController notifications;

  /// Incoming "approve this signature" requests for this device.
  final SignApprovals approvals;
  final String? Function()? _sessionId;

  /// Login `session_id` when the integrator supplied it.
  String? get sessionId => _sessionId?.call();

  /// Stops the live stream and the controllers fed by it.
  Future<void> dispose() async {
    notifications.dispose();
    approvals.dispose();
    await live.dispose();
  }
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
