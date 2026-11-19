import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/sales/models.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/money.dart';

String leadStatusLabel(AppLocalizations l, String s) => switch (s) {
  LeadStatus.open => l.salesStatusOpen,
  LeadStatus.won => l.salesStatusWon,
  LeadStatus.lost => l.salesStatusLost,
  _ => s,
};

Tone leadTone(String s) => switch (s) {
  LeadStatus.won => Tone.ok,
  LeadStatus.lost => Tone.error,
  _ => Tone.info,
};

/// `۲۵–۴۹٪` for the bucket `25-49`.
String bucketLabel(String bucket) =>
    '${toPersianDigits(bucket.replaceAll('-', '–'))}٪';

/// One lead as a card: title, value, probability, owner and status.
class LeadTile extends StatelessWidget {
  const LeadTile({super.key, required this.lead, required this.onTap});
  final Lead lead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    return Padding(
      key: ValueKey('lead-${lead.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lead.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusPill(
                  leadStatusLabel(l, lead.status),
                  tone: leadTone(lead.status),
                ),
              ],
            ),
            const SizedBox(height: 4),
            AmountText(lead.value, withUnit: true),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: lead.probability / 100),
            const SizedBox(height: 4),
            Text(
              [
                '${toPersianDigits(lead.probability)}٪',
                lead.owner.displayName,
                ?lead.customerName,
              ].join(' · '),
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}
