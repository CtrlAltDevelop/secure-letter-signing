import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/finance/models.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/money.dart';

String kindLabel(AppLocalizations l, String kind) => switch (kind) {
  FinanceKind.cash => l.financeKindCash,
  FinanceKind.cheque => l.financeKindCheque,
  FinanceKind.probable => l.financeKindProbable,
  FinanceKind.voided => l.financeKindVoid,
  _ => kind,
};

String directionLabel(AppLocalizations l, String d) =>
    d == FinanceDirection.receipt ? l.financeDirReceipt : l.financeDirPayment;

String statusLabel(AppLocalizations l, String s) => switch (s) {
  FinanceStatus.confirmed => l.financeStatusConfirmed,
  FinanceStatus.pending => l.financeStatusPending,
  FinanceStatus.voided => l.financeStatusVoid,
  _ => s,
};

Tone statusTone(String s) => switch (s) {
  FinanceStatus.confirmed => Tone.ok,
  FinanceStatus.pending => Tone.warn,
  _ => Tone.neutral,
};

/// Receipts are green, payments red.
Color directionColor(String direction) =>
    direction == FinanceDirection.receipt ? Tokens.ok : Tokens.error;

/// One finance document as a card: amount, kind and status pills, dates, description.
class FinanceDocTile extends StatelessWidget {
  const FinanceDocTile({super.key, required this.doc, required this.onTap});
  final FinanceDoc doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final due = doc.dueDate;
    final lines = [
      formatJalaliDate(doc.date),
      if (doc.isPending && due != null)
        '${l.financeDueDate}: ${formatJalaliDate(due)}',
      ?doc.customerName,
    ];
    return Padding(
      key: ValueKey('fin-${doc.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AmountText(
                    doc.amount,
                    withUnit: true,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: doc.isVoid
                          ? scheme.onSurfaceVariant
                          : directionColor(doc.direction),
                      decoration: doc.isVoid
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                if (doc.overdue && doc.isPending)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: StatusPill(l.financeOverdue, tone: Tone.error),
                  ),
                StatusPill(
                  statusLabel(l, doc.status),
                  tone: statusTone(doc.status),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${directionLabel(l, doc.direction)} · ${kindLabel(l, doc.kind)}',
              style: muted,
            ),
            Text(lines.join(' · '), style: muted),
            if (doc.description.isNotEmpty)
              Text(
                doc.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
