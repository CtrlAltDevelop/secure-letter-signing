import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/crm/crm_api.dart';
import 'package:letter_signing/crm/crm_ui.dart';
import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show fmtDateTime;
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/widgets/choice_row.dart';

/// The append-only timeline of a customer file (newest first), filterable by kind, with a
/// field to add a note when the viewer may (`can.event`). Events cannot be edited or deleted.
class CustomerTimelineTab extends StatefulWidget {
  const CustomerTimelineTab({
    super.key,
    required this.api,
    required this.customerId,
    required this.canAdd,
  });
  final CrmApi api;
  final String customerId;
  final bool canAdd;

  @override
  State<CustomerTimelineTab> createState() => _CustomerTimelineTabState();
}

class _CustomerTimelineTabState extends State<CustomerTimelineTab> {
  final _note = TextEditingController();
  List<TimelineEvent>? _events;
  Object? _error;
  String _kind = '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final v = await widget.api.events(widget.customerId, kind: _kind);
      if (mounted) setState(() => _events = v);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _add() async {
    final text = _note.text.trim();
    if (text.isEmpty || _sending) return;
    final failed = AppLocalizations.of(context).crmSaveFailed;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await widget.api.addEvent(widget.customerId, summary: text);
      _note.clear();
      await _load();
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final events = _events;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              if (widget.canAdd)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('crm-note'),
                        controller: _note,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(hintText: l.crmNoteHint),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('crm-note-add'),
                      tooltip: l.crmNoteAdd,
                      onPressed: _sending ? null : () => unawaited(_add()),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ChoiceRow(
                options: {
                  '': l.crmFilterAll,
                  for (final k in const [
                    EventKind.note,
                    EventKind.call,
                    EventKind.task,
                    EventKind.meeting,
                    EventKind.letter,
                    EventKind.finance,
                    EventKind.lead,
                    EventKind.system,
                  ])
                    k: eventKindLabel(l, k),
                },
                value: _kind,
                onChanged: (v) {
                  setState(() {
                    _kind = v;
                    _events = null;
                  });
                  unawaited(_load());
                },
              ),
              if (_error != null && events == null)
                Text('$_error')
              else if (events == null)
                const Center(child: CircularProgressIndicator())
              else if (events.isEmpty)
                EmptyState(icon: Icons.timeline, title: l.crmTimelineEmpty)
              else
                for (final e in events) _EventTile(event: e),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final at = event.at;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(eventKindIcon(event.kind)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.summary),
                const SizedBox(height: 4),
                Text(
                  [
                    eventKindLabel(l, event.kind),
                    ?event.by?.displayName,
                    if (at != null) fmtDateTime(at.toLocal()),
                  ].join(' · '),
                  style: muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
