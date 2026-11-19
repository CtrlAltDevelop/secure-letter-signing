import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/crm/crm_env.dart';
import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Import customers from a CSV or xlsx file (permission `customer.import`): pick a file,
/// upload it, then show how many rows were created or skipped and each failing row.
class CustomerImportScreen extends StatefulWidget {
  const CustomerImportScreen({super.key, required this.env});
  final CrmEnv env;

  @override
  State<CustomerImportScreen> createState() => _CustomerImportScreenState();
}

class _CustomerImportScreenState extends State<CustomerImportScreen> {
  ImportResult? _result;
  String? _error;
  bool _busy = false;

  Future<void> _pick() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await widget.env.pickFile();
      if (file == null) return;
      final ext = file.name.toLowerCase().endsWith('.xlsx') ? 'xlsx' : 'csv';
      final res = await widget.env.api.importFile(
        format: ext,
        name: file.name,
        bytes: file.bytes,
      );
      if (mounted) setState(() => _result = res);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '${l.crmImportFailed}\n$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: Text(l.crmImport)),
      body: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Text(l.crmImportHelp),
                FilledButton.icon(
                  key: const ValueKey('crm-import-pick'),
                  onPressed: _busy ? null : () => unawaited(_pick()),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(l.crmImportPick),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (r != null) ...[
                  Text(
                    l.crmImportSummary(
                      toPersianDigits(r.created),
                      toPersianDigits(r.skipped),
                      toPersianDigits(r.errors.length),
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final e in r.errors)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.error_outline),
                      title: Text(e.$2),
                      subtitle: Text(l.crmImportRow(toPersianDigits(e.$1))),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
