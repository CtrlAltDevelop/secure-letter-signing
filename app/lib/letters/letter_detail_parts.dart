import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/theme/widgets.dart';

String methodLabel(AppLocalizations l, String m) => switch (m) {
  'pin' => l.signMethodPin,
  'biometric' => l.signMethodBiometric,
  _ => m,
};

String decisionLabel(AppLocalizations l, String d) => switch (d) {
  'approved' => l.decisionApproved,
  'rejected' => l.decisionRejected,
  _ => l.decisionPending,
};

/// One signer on the signing timeline: avatar, decision pill, time, device and method.
class TimelineStep extends StatelessWidget {
  const TimelineStep({
    super.key,
    required this.participant,
    required this.signature,
    required this.opened,
    required this.color,
    required this.last,
  });
  final Participant participant;
  final SignatureInfo? signature;
  final bool opened;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final p = participant;
    final sig = signature;
    final when = p.decidedAt ?? sig?.signedAt;
    final tone = switch (p.decision) {
      'approved' => Tone.ok,
      'rejected' => Tone.error,
      _ => opened ? Tone.info : Tone.neutral,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                PersonAvatar(p.displayName, color: color),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(
                        opened && p.decision.isEmpty
                            ? l.decisionOpened
                            : decisionLabel(l, p.decision),
                        tone: tone,
                      ),
                    ],
                  ),
                  if (when != null) Text(fmtDateTime(when), style: muted),
                  if (sig != null)
                    Text(
                      [
                        if (sig.deviceName.isNotEmpty) sig.deviceName,
                        if (sig.method.isNotEmpty) methodLabel(l, sig.method),
                      ].join('  -  '),
                      style: muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (sig != null && sig.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('"${sig.note}"'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sealed paraphs (initials) of a letter: who, how, from which device, when.
class ParaphList extends StatelessWidget {
  const ParaphList({super.key, required this.paraphs});
  final List<ParaphInfo> paraphs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12.5,
    );
    if (paraphs.isEmpty) {
      return AppCard(child: Text(l.paraphNone));
    }
    return AppCard(
      child: Column(
        children: [
          for (final p in paraphs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: PersonAvatar(p.signerName, size: 32),
              title: Text(p.signerName),
              subtitle: Text(
                [
                  methodLabel(l, p.method),
                  if (p.deviceName.isNotEmpty) p.deviceName,
                  if (p.paraphedAt != null) fmtDateTime(p.paraphedAt!),
                ].join('  -  '),
                style: muted,
              ),
            ),
        ],
      ),
    );
  }
}
