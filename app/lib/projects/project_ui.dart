import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/project_controller.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome;

/// Persian names for project enums.
String projectStatusLabel(AppLocalizations l, String status) =>
    switch (status) {
      ProjectStatus.active => l.projectStatusActive,
      ProjectStatus.done => l.projectStatusDone,
      ProjectStatus.archived => l.projectStatusArchived,
      _ => status,
    };

Tone projectStatusTone(String status) => switch (status) {
  ProjectStatus.active => Tone.info,
  ProjectStatus.done => Tone.ok,
  _ => Tone.neutral,
};

String projectRoleLabel(AppLocalizations l, String role) => switch (role) {
  ProjectRole.manager => l.roleManager,
  ProjectRole.member => l.roleMember,
  ProjectRole.viewer => l.roleViewer,
  _ => role,
};

String columnSortLabel(AppLocalizations l, ColumnSort sort) => switch (sort) {
  ColumnSort.manual => l.sortManual,
  ColumnSort.createdAsc => l.sortCreatedAsc,
  ColumnSort.createdDesc => l.sortCreatedDesc,
  ColumnSort.dueAsc => l.sortDueAsc,
  ColumnSort.dueDesc => l.sortDueDesc,
  ColumnSort.updatedAsc => l.sortUpdatedAsc,
  ColumnSort.updatedDesc => l.sortUpdatedDesc,
};

/// Shows a snackbar for a failed [outcome]; does nothing for [ActionOutcome.ok].
void reportOutcome(
  BuildContext context,
  ActionOutcome outcome, [
  Object? error,
]) {
  if (outcome == ActionOutcome.ok || !context.mounted) return;
  final l = AppLocalizations.of(context);
  final text = switch (outcome) {
    ActionOutcome.conflict => l.projectConflict,
    ActionOutcome.forbidden => l.taskForbidden,
    ActionOutcome.notFound => l.projectNotFound,
    _ => '${error ?? l.taskActionFailed}',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Asks for one line of text; resolves to the trimmed text or null when cancelled or empty.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initial = '',
  String? hint,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPrompt(
    title: title,
    confirmLabel: confirmLabel,
    initial: initial,
    hint: hint,
  ),
);

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.confirmLabel,
    required this.initial,
    this.hint,
  });

  final String title;
  final String confirmLabel;
  final String initial;
  final String? hint;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('prompt-field'),
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(hintText: widget.hint),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('prompt-confirm'),
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
