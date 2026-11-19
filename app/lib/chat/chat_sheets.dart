import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/workspace/models.dart';

/// Searchable single choice of a colleague (DM start, @mention). Pops with the user.
Future<UserRef?> showUserPickSheet(
  BuildContext context, {
  required String title,
  required Future<List<UserRef>> Function() load,
}) => showModalBottomSheet<UserRef>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _UserPickSheet(title: title, load: load),
);

class _UserPickSheet extends StatefulWidget {
  const _UserPickSheet({required this.title, required this.load});
  final String title;
  final Future<List<UserRef>> Function() load;

  @override
  State<_UserPickSheet> createState() => _UserPickSheetState();
}

class _UserPickSheetState extends State<_UserPickSheet> {
  late final Future<List<UserRef>> _future = widget.load();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: widget.title,
                  ),
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                ),
              ),
              Flexible(
                child: FutureBuilder<List<UserRef>>(
                  future: _future,
                  builder: (context, snap) {
                    final all = snap.data;
                    if (all == null) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      );
                    }
                    final rows = [
                      for (final u in all)
                        if (_q.isEmpty ||
                            u.fullName.toLowerCase().contains(_q) ||
                            u.email.toLowerCase().contains(_q))
                          u,
                    ];
                    if (rows.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l.peopleEmpty),
                      );
                    }
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        for (final u in rows)
                          ListTile(
                            dense: true,
                            leading: UserAvatar(
                              fullName: u.fullName,
                              email: u.email,
                              radius: 16,
                            ),
                            title: Text(u.displayName),
                            onTap: () => Navigator.pop(context, u),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Who has seen a message and when. [load] returns null on failure.
Future<void> showChatSeenSheet(
  BuildContext context,
  Future<ChatSeenResult?> Function() load,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _SeenSheet(load: load),
);

class _SeenSheet extends StatelessWidget {
  const _SeenSheet({required this.load});
  final Future<ChatSeenResult?> Function() load;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: FutureBuilder<ChatSeenResult?>(
          future: load(),
          builder: (context, snap) {
            final done = snap.connectionState == ConnectionState.done;
            final res = snap.data;
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
              children: [
                Text(
                  l.chatSeenTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (!done)
                  const Center(child: CircularProgressIndicator())
                else if (res == null)
                  Text(l.chatSeenFailed)
                else if (!res.tracked)
                  Text(l.chatSeenUntracked)
                else if (res.seen.isEmpty)
                  Text(l.chatSeenEmpty)
                else
                  for (final e in res.seen)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(
                        fullName: e.user.fullName,
                        email: e.user.email,
                        radius: 16,
                      ),
                      title: Text(e.user.displayName),
                      trailing: e.at == null
                          ? null
                          : Text(formatJalaliDateTime(e.at!)),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
