import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';

/// Manager view: title and participants only (never bodies). Unlist/relist published letters.
class LettersAdminScreen extends StatefulWidget {
  const LettersAdminScreen({super.key, required this.env});
  final LettersEnv env;

  @override
  State<LettersAdminScreen> createState() => _LettersAdminScreenState();
}

class _LettersAdminScreenState extends State<LettersAdminScreen> {
  List<AdminLetter> _rows = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final rows = await widget.env.api.adminList();
      if (mounted)
        setState(() {
          _rows = rows;
          _error = null;
          _loading = false;
        });
    } on Object catch (e) {
      if (mounted)
        setState(() {
          _error = e;
          _loading = false;
        });
    }
  }

  Future<void> _toggle(AdminLetter l) async {
    try {
      await widget.env.api.setUnlisted(l.brief.id, unlisted: !l.brief.unlisted);
      await _load();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('All letters (manager)')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('$_error'),
                ),
              ],
            )
          : ListView(
              children: [
                for (final l in _rows)
                  ListTile(
                    key: ValueKey(l.brief.id),
                    title: Text('#${l.brief.no}  ${l.brief.title}'),
                    subtitle: Text(
                      '${statusLabel(l.brief.status)}${l.brief.unlisted ? ' (unlisted)' : ''} - '
                      'by ${l.creatorEmail}\n'
                      '${[for (final p in l.participants) '${p.displayName} (${p.role})'].join(', ')}',
                    ),
                    isThreeLine: true,
                    trailing: l.brief.status == LetterStatus.published
                        ? TextButton(
                            onPressed: () => _toggle(l),
                            child: Text(l.brief.unlisted ? 'Relist' : 'Unlist'),
                          )
                        : null,
                  ),
              ],
            ),
    ),
  );
}
