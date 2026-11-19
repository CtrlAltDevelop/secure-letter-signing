import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:letter_signing/crm/crm_api.dart';
import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/l10n/tr.dart';

/// Search-as-you-type dialog that returns the chosen customer file, or null when dismissed.
Future<Customer?> pickCustomer(BuildContext context, CrmApi api) =>
    showDialog<Customer>(
      context: context,
      builder: (_) => _CustomerPickerDialog(api: api),
    );

class _CustomerPickerDialog extends StatefulWidget {
  const _CustomerPickerDialog({required this.api});
  final CrmApi api;

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  List<Customer> _rows = const [];
  bool _loading = true;
  Object? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(_load(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.api.list(CustomerFilter(q: q), limit: 30);
      if (mounted) setState(() => _rows = rows);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_load(q.trim())),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr.customerPickTitle),
    content: SizedBox(
      width: 360,
      height: 380,
      child: Column(
        children: [
          TextField(
            key: const ValueKey('customer-picker-search'),
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: tr.customerPickSearch,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _body()),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr.commonCancel),
      ),
    ],
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('$_error'));
    if (_rows.isEmpty) return Center(child: Text(tr.customerPickEmpty));
    return ListView(
      children: [
        for (final c in _rows)
          ListTile(
            key: ValueKey('customer-pick-${c.id}'),
            title: Text(c.name),
            onTap: () => Navigator.pop(context, c),
          ),
      ],
    );
  }
}
