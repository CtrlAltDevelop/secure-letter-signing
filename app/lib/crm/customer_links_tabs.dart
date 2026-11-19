import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/crm/crm_env.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_detail_screen.dart';
import 'package:letter_signing/letters/letters_env.dart' show letterStatusLabel;
import 'package:letter_signing/letters/models.dart' show LetterBrief;
import 'package:letter_signing/letters/letter_widgets.dart' show fmtDateTime;
import 'package:letter_signing/meetings/meeting_detail_screen.dart';
import 'package:letter_signing/meetings/meeting_form_screen.dart';
import 'package:letter_signing/meetings/meeting_ui.dart';
import 'package:letter_signing/meetings/models.dart' show MeetingBrief;
import 'package:letter_signing/tasks/models.dart' show TaskBrief, TaskDraft;
import 'package:letter_signing/tasks/task_card.dart';
import 'package:letter_signing/tasks/task_detail_screen.dart';
import 'package:letter_signing/tasks/task_form_screen.dart';
import 'package:letter_signing/theme/widgets.dart';

/// A reloadable list with an optional "create" button; shared by the task, meeting and
/// letter tabs of a customer file.
class _LinkedList<T> extends StatefulWidget {
  const _LinkedList({
    required this.load,
    required this.tile,
    required this.emptyIcon,
    required this.emptyText,
    this.onCreate,
    this.createLabel = '',
  });
  final Future<List<T>> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function() reload) tile;
  final IconData emptyIcon;
  final String emptyText;
  final Future<void> Function()? onCreate;
  final String createLabel;

  @override
  State<_LinkedList<T>> createState() => _LinkedListState<T>();
}

class _LinkedListState<T> extends State<_LinkedList<T>> {
  List<T>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final v = await widget.load();
      if (mounted) setState(() => _items = v);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _create() async {
    await widget.onCreate!();
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              if (widget.onCreate != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    key: const ValueKey('crm-linked-create'),
                    onPressed: () => unawaited(_create()),
                    icon: const Icon(Icons.add),
                    label: Text(widget.createLabel),
                  ),
                ),
              if (_error != null && items == null)
                Text('$_error')
              else if (items == null)
                const Center(child: CircularProgressIndicator())
              else if (items.isEmpty)
                EmptyState(icon: widget.emptyIcon, title: widget.emptyText)
              else
                for (final i in items) widget.tile(context, i, _reload),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _push(BuildContext context, Widget page) async {
  await Navigator.of(context)
      .push<Object>(MaterialPageRoute(builder: (_) => page));
}

/// Tasks linked to the file; "new task" opens the task form with the customer preset.
class CustomerTasksTab extends StatelessWidget {
  const CustomerTasksTab({
    super.key,
    required this.env,
    required this.customerId,
    required this.canCreate,
  });
  final CrmEnv env;
  final String customerId;
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _LinkedList<TaskBrief>(
      load: () => env.api.tasks(customerId),
      emptyIcon: Icons.task_alt_outlined,
      emptyText: l.crmTasksEmpty,
      createLabel: l.crmTaskNew,
      onCreate: canCreate && env.tasks.canCreate
          ? () => _push(
              context,
              TaskFormScreen(
                env: env.tasks,
                initialDraft: TaskDraft(customerId: customerId),
              ),
            )
          : null,
      tile: (context, t, reload) => TaskCard(
        task: t,
        onTap: () async {
          await _push(context, TaskDetailScreen(env: env.tasks, taskId: t.id));
          await reload();
        },
      ),
    );
  }
}

/// Meetings linked to the file; "new meeting" opens the form with the customer preset.
class CustomerMeetingsTab extends StatelessWidget {
  const CustomerMeetingsTab({
    super.key,
    required this.env,
    required this.customerId,
    required this.canCreate,
  });
  final CrmEnv env;
  final String customerId;
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _LinkedList<MeetingBrief>(
      load: () => env.api.meetings(customerId),
      emptyIcon: Icons.groups_outlined,
      emptyText: l.crmMeetingsEmpty,
      createLabel: l.crmMeetingNew,
      onCreate: canCreate
          ? () => _push(
              context,
              MeetingFormScreen(env: env.meetings, customerId: customerId),
            )
          : null,
      tile: (context, m, reload) => AppCard(
        onTap: () async {
          await _push(
            context,
            MeetingDetailScreen(env: env.meetings, meetingId: m.id),
          );
          await reload();
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.title, style: Theme.of(context).textTheme.titleSmall),
                  if (m.startsAt != null)
                    Text(fmtDateTime(m.startsAt!.toLocal())),
                ],
              ),
            ),
            StatusPill(meetingStatusLabel(l, m.status)),
          ],
        ),
      ),
    );
  }
}

/// Letters linked through the secretariat customer links (read-only list).
class CustomerLettersTab extends StatelessWidget {
  const CustomerLettersTab({
    super.key,
    required this.env,
    required this.customerId,
  });
  final CrmEnv env;
  final String customerId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _LinkedList<LetterBrief>(
      load: () => env.api.letters(customerId),
      emptyIcon: Icons.mail_outline,
      emptyText: l.crmLettersEmpty,
      tile: (context, x, reload) => AppCard(
        onTap: () => _push(
          context,
          LetterDetailScreen(env: env.letters, letterId: x.id),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(x.title, style: Theme.of(context).textTheme.titleSmall),
                  if (x.numberLabel.isNotEmpty) Text(x.numberLabel),
                ],
              ),
            ),
            StatusPill(letterStatusLabel(l, x.status)),
          ],
        ),
      ),
    );
  }
}
