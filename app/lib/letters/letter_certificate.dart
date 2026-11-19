import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_detail_parts.dart';

List<Map<String, dynamic>> _rows(Object? raw) => [
  if (raw is List)
    for (final e in raw)
      if (e is Map) Map<String, dynamic>.from(e),
];

/// Shows the signature certificate (re-verified by the server): signatures and, when present,
/// the paraphs with their own verification result.
Future<void> showCertificateDialog(
  BuildContext context,
  Map<String, dynamic> cert,
) {
  final l = AppLocalizations.of(context);
  final sigs = _rows(cert['signatures']);
  final paraphs = _rows(cert['paraphs']);
  final paraphsOk = cert['paraphs_verified'] != false;
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(cert['all_verified'] == true ? l.certVerified : l.certFailed),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in sigs) _SignatureRow(row: s),
            if (sigs.isEmpty) Text(l.certNoSignatures),
            if (paraphs.isNotEmpty) ...[
              const Divider(),
              Text(
                paraphsOk ? l.certParaphsVerified : l.certParaphsFailed,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final p in paraphs) _ParaphRow(row: p),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonClose),
        ),
      ],
    ),
  );
}

class _SignatureRow extends StatelessWidget {
  const _SignatureRow({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ok = row['verified'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '${row['signer']}: ${decisionLabel(l, '${row['decision']}')}\n'
        '${l.certDevice('${row['device'] ?? ''}')}\n'
        '${row['signed_at'] ?? ''}\n'
        '${ok ? l.certValid : l.certInvalid}',
      ),
    );
  }
}

class _ParaphRow extends StatelessWidget {
  const _ParaphRow({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ok = row['verified'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '${row['signer'] ?? row['signer_name'] ?? ''} - '
        '${methodLabel(l, '${row['method'] ?? ''}')} - '
        '${ok ? l.certValid : l.certInvalid}',
      ),
    );
  }
}
