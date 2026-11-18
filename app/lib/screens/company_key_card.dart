import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/keys/company_key_service.dart';
import 'package:letter_signing/keys/key_vault.dart';
import 'package:letter_signing/screens/auth_screens.dart';

/// Manager: create / rotate the company key (public letters) and give it to new members and devices.
class CompanyKeyCard extends StatefulWidget {
  const CompanyKeyCard({
    super.key,
    required this.api,
    required this.vault,
    required this.service,
  });
  final ApiClient api;
  final KeyVault vault;
  final CompanyKeyService service;

  @override
  State<CompanyKeyCard> createState() => _CompanyKeyCardState();
}

class _CompanyKeyCardState extends State<CompanyKeyCard> {
  late Future<({int version, bool rotate, int missing})> _status = _load();

  Future<({int version, bool rotate, int missing})> _load() async {
    final status = await widget.api.call(
      'GET',
      '/keys/company/status',
    ) as Map<String, dynamic>;
    final version = status['version'] as int;
    final missing = version == 0
        ? 0
        : (await widget.api.call(
            'GET',
            '/keys/company/missing',
          ) as List).length;
    return (
      version: version,
      rotate: status['needs_rotation'] as bool,
      missing: missing,
    );
  }

  Future<void> _run(
    String reason,
    Future<Object?> Function(UnlockedKey key) action,
    String done,
  ) async {
    final key = await widget.vault.unlock(context, reason: reason);
    if (key == null || !mounted) return;
    final ok = await runGuarded(context, () async {
      await action(key);
    });
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    }
    setState(() {
      _status = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _status,
      builder: (context, snap) {
        final s = snap.data;
        if (s == null) {
          return ListTile(
            title: const Text('Company key'),
            subtitle: Text(snap.hasError ? '${snap.error}' : 'Loading…'),
          );
        }
        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company key',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  s.version == 0
                      ? 'None yet. Public letters cannot be sent until you create it.'
                      : 'Version ${s.version}'
                            '${s.rotate ? ' · a member left: rotate it' : ''}'
                            '${s.missing > 0 ? ' · ${s.missing} key(s) do not have it yet' : ''}',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (s.version == 0 || s.rotate)
                      FilledButton(
                        onPressed: () => _run(
                          s.version == 0
                              ? 'Create the company key'
                              : 'Rotate the company key',
                          widget.service.createOrRotateCompanyKey,
                          'Company key created',
                        ),
                        child: Text(
                          s.version == 0 ? 'Create company key' : 'Rotate',
                        ),
                      ),
                    if (s.missing > 0)
                      FilledButton.tonal(
                        onPressed: () => _run(
                          'Give the company key to new members',
                          widget.service.onboardMissing,
                          'Company key shared',
                        ),
                        child: Text('Give to ${s.missing} new key(s)'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
