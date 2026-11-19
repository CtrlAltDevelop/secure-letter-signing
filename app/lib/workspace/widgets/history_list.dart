import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';

/// The audited changes of a subject, newest first as the server sends them.
class HistoryList extends StatelessWidget {
  const HistoryList({super.key, required this.entries});

  /// Null while loading.
  final List<HistoryEntry>? entries;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = entries;
    if (rows == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (rows.isEmpty) {
      return EmptyState(icon: Icons.history, title: l.historyEmpty);
    }
    return Column(children: [for (final e in rows) _HistoryRow(entry: e)]);
  }
}

/// Human text for one stored value; ISO timestamps become Jalali dates.
String formatHistoryValue(AppLocalizations l, Object? value) {
  if (value == null) return l.historyNone;
  if (value is bool) return value ? l.historyYes : l.historyNo;
  if (value is String) {
    final date = DateTime.tryParse(value);
    if (date != null && value.contains('T')) {
      return formatJalaliDateTime(date);
    }
    return value;
  }
  if (value is List) {
    return value.map((e) => formatHistoryValue(l, e)).join('، ');
  }
  if (value is Map) {
    final text = value['text'];
    if (text is String) return text;
    return value.values.map((e) => formatHistoryValue(l, e)).join('، ');
  }
  return toPersianDigits(value);
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final actor = entry.actor?.displayName ?? l.historySystem;
    final change =
        '${formatHistoryValue(l, entry.oldValue)}  ←  '
        '${formatHistoryValue(l, entry.newValue)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_note, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.historyChanged(actor, historyFieldLabel(l, entry.field)),
                ),
                Text(
                  change,
                  style: muted,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.at != null)
                  Text(formatJalaliDateTime(entry.at!), style: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Persian name of a changed field; unknown fields show their key.
String historyFieldLabel(AppLocalizations l, String field) => switch (field) {
  'title' => l.fieldTitle,
  'description' => l.fieldDescription,
  'priority' => l.fieldPriority,
  'status' => l.fieldStatus,
  'due_at' => l.fieldDue,
  'start_at' => l.fieldStart,
  'progress' => l.fieldProgress,
  'all_day' => l.fieldAllDay,
  'owners' => l.fieldOwners,
  'approvers' => l.fieldApprovers,
  'followers' => l.fieldFollowers,
  'checklist' => l.fieldChecklist,
  _ => field,
};
