import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';

/// The secretariat number as a small outlined chip (`۱۴۰۵/۰۰۱۲`); nothing when empty.
class NumberLabelChip extends StatelessWidget {
  const NumberLabelChip(this.number, {super.key});
  final String number;

  @override
  Widget build(BuildContext context) {
    if (number.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.primary),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        toPersianDigits(number),
        textDirection: TextDirection.ltr,
        style: TextStyle(
          color: scheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _CardAction { labels, archive }

/// One letter in the list: number, status, title, labels, and a menu for labels and archive.
class LetterCard extends StatelessWidget {
  const LetterCard({
    super.key,
    required this.letter,
    required this.depth,
    required this.mine,
    required this.labels,
    required this.onTap,
    required this.onToggleArchive,
    this.onEditLabels,
  });
  final LetterBrief letter;
  final int depth;
  final bool mine;
  final List<LabelInfo> labels;
  final VoidCallback onTap;
  final VoidCallback onToggleArchive;
  final VoidCallback? onEditLabels;

  void _onAction(_CardAction a) => switch (a) {
    _CardAction.labels => onEditLabels?.call(),
    _CardAction.archive => onToggleArchive(),
  };

  Widget _menu(AppLocalizations l) => PopupMenuButton<_CardAction>(
    tooltip: l.lettersMenu,
    padding: EdgeInsets.zero,
    onSelected: _onAction,
    itemBuilder: (_) => [
      if (onEditLabels != null)
        PopupMenuItem(
          value: _CardAction.labels,
          child: Text(l.lettersEditLabels),
        ),
      PopupMenuItem(
        value: _CardAction.archive,
        child: Text(letter.archived ? l.lettersUnarchive : l.lettersArchive),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final date = fmtDate(letter.sentAt ?? letter.createdAt);
    final public = letter.visibility == 'public';
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (depth > 0) ...[
            Icon(
              Icons.subdirectory_arrow_left,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('#${toPersianDigits(letter.no)}', style: muted),
                    NumberLabelChip(letter.numberLabel),
                    StatusChip(letter.status),
                    if (letter.archived)
                      Icon(
                        Icons.archive_outlined,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    if (mine)
                      Icon(Icons.edit_note, size: 18, color: scheme.secondary),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  letter.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    Text(
                      mine ? l.lettersCreatedByYou : l.lettersSharedWithYou,
                      style: muted,
                    ),
                    Text(date, style: muted),
                    Text(
                      public ? l.lettersPublic : l.lettersPrivate,
                      style: muted,
                    ),
                    if (letter.referralCount > 0)
                      Text(
                        l.lettersReferralCount(
                          toPersianDigits(letter.referralCount),
                        ),
                        style: muted,
                      ),
                  ],
                ),
                if (letter.labelIds.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  LabelChips(labels: labels, selected: letter.labelIds.toSet()),
                ],
              ],
            ),
          ),
          _menu(l),
        ],
      ),
    );
  }
}

/// Edits the labels of a letter and saves them with `PUT /subjects/{id}/labels`. Pops the saved
/// label ids, or null when dismissed or the save failed (the error is shown).
Future<List<int>?> showLetterLabelsSheet(
  BuildContext context, {
  required LettersEnv env,
  required String subjectId,
  required List<int> selected,
}) async {
  final labels = await env.labels();
  if (!context.mounted) return null;
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LabelsSheet(
      env: env,
      subjectId: subjectId,
      labels: labels,
      selected: selected,
    ),
  );
}

class _LabelsSheet extends StatefulWidget {
  const _LabelsSheet({
    required this.env,
    required this.subjectId,
    required this.labels,
    required this.selected,
  });
  final LettersEnv env;
  final String subjectId;
  final List<LabelInfo> labels;
  final List<int> selected;

  @override
  State<_LabelsSheet> createState() => _LabelsSheetState();
}

class _LabelsSheetState extends State<_LabelsSheet> {
  late Set<int> _chosen = widget.selected.toSet();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await widget.env.workspace.setLabels(
        widget.subjectId,
        _chosen.toList(),
      );
      if (mounted) Navigator.of(context).pop(saved);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.lettersEditLabels,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (widget.labels.isEmpty)
              Text(l.lettersNoLabels)
            else
              LabelChips(
                labels: widget.labels,
                selected: _chosen,
                onChanged: (v) => setState(() => _chosen = v),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : () => unawaited(_save()),
              child: Text(l.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
