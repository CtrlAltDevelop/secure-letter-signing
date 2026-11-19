import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// The ways to sign: PIN, this device's fingerprint/face, or asking another of your devices.
class SignMethods extends StatelessWidget {
  const SignMethods({
    super.key,
    required this.pin,
    required this.pinError,
    required this.busy,
    required this.onPin,
    required this.onBiometric,
    required this.devices,
    required this.onAsk,
    this.onEnableBiometric,
    this.actionLabel,
  });
  final TextEditingController pin;
  final String? pinError;
  final bool busy;
  final VoidCallback onPin;

  /// Null when this session is not flagged biometric.
  final VoidCallback? onBiometric;
  final List<SessionInfo> devices;
  final void Function(SessionInfo device) onAsk;

  /// Non-null when biometrics are available here but this session is not enrolled.
  final VoidCallback? onEnableBiometric;

  /// Label of the PIN button; defaults to "sign with PIN".
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 13,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PinField(
            controller: pin,
            label: l.signPinLabel,
            enabled: !busy,
            errorText: pinError,
            onSubmitted: onPin,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : onPin,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open_outlined),
            label: Text(busy ? l.signBusy : (actionLabel ?? l.signWithPin)),
          ),
          if (onBiometric != null || devices.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l.signOrBiometric, style: muted),
            const SizedBox(height: 8),
          ],
          if (onBiometric != null)
            OutlinedButton.icon(
              onPressed: busy ? null : onBiometric,
              icon: const Icon(Icons.fingerprint),
              label: Text(l.signFingerprint),
            ),
          if (onEnableBiometric != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: busy ? null : onEnableBiometric,
                icon: const Icon(Icons.fingerprint),
                label: Text(l.signEnableBiometric),
              ),
            ),
          for (final d in devices) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : () => onAsk(d),
              icon: Icon(platformIcon(d.platform)),
              label: Text(l.signAskDevice(d.displayName)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown while another device of the user decides.
class WaitingForApproval extends StatelessWidget {
  const WaitingForApproval({
    super.key,
    required this.device,
    required this.onCancel,
  });
  final String device;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Text(
            l.signWaiting(device),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(l.signWaitingHint, textAlign: TextAlign.center, style: muted),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onCancel, child: Text(l.commonCancel)),
        ],
      ),
    );
  }
}

/// Big approve / reject tile.
class DecisionChoice extends StatelessWidget {
  const DecisionChoice({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : null,
            borderRadius: BorderRadius.circular(Tokens.radius),
            border: Border.all(
              color: selected ? color : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
