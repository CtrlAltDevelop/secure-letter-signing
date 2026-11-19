import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/workspace/models.dart';

/// Bottom sheet listing who opened a subject and when they last did.
Future<void> showSeenBySheet(
  BuildContext context,
  Future<List<SeenEntry>> Function() load,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _SeenBySheet(load: load),
);

class _SeenBySheet extends StatefulWidget {
  const _SeenBySheet({required this.load});
  final Future<List<SeenEntry>> Function() load;

  @override
  State<_SeenBySheet> createState() => _SeenBySheetState();
}

class _SeenBySheetState extends State<_SeenBySheet> {
  late final Future<List<SeenEntry>> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: FutureBuilder<List<SeenEntry>>(
          future: _future,
          builder: (context, snap) {
            final rows = snap.data;
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
              children: [
                Text(
                  l.seenByTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (snap.hasError)
                  Text(l.seenByFailed)
                else if (rows == null)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (rows.isEmpty)
                  Text(l.seenByEmpty)
                else
                  for (final e in rows)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.visibility_outlined),
                      title: Text(e.user.displayName),
                      subtitle: e.lastAt == null
                          ? null
                          : Text(formatRelative(e.lastAt!)),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
