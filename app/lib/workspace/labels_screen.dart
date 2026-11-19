import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';
import 'package:letter_signing/workspace/widgets/label_create_sheet.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Manage labels: organisation labels (changeable only by the company manager) and personal
/// labels (everyone). Create, rename, recolour and deactivate; labels are never deleted.
class LabelsScreen extends StatefulWidget {
  const LabelsScreen({
    super.key,
    required this.api,
    required this.isManager,
    this.onChanged,
  });

  final WorkspaceApi api;
  final bool isManager;

  /// Called after any change, so cached label lists elsewhere can be dropped.
  final VoidCallback? onChanged;

  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  List<LabelInfo> _labels = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final labels = await widget.api.allLabels();
      if (!mounted) return;
      setState(() {
        _labels = labels;
        _error = null;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  bool _canEdit(LabelInfo label) => label.scope != 'org' || widget.isManager;

  void _snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  /// Runs a write; a duplicate name is explained, other failures show their message.
  Future<void> _write(Future<Object?> Function() action) async {
    try {
      await action();
    } on ConflictException {
      if (mounted) _snack(AppLocalizations.of(context).labelDuplicate);
      return;
    } on ForbiddenException {
      if (mounted) _snack(AppLocalizations.of(context).taskForbidden);
      return;
    } on Object catch (e) {
      _snack('$e');
      return;
    }
    widget.onChanged?.call();
    await _load();
  }

  Future<void> _create() async {
    final edit = await showLabelEditor(context, canOrg: widget.isManager);
    if (edit == null) return;
    await _write(
      () => widget.api.createLabel(
        name: edit.name,
        color: edit.color,
        scope: edit.scope,
      ),
    );
  }

  Future<void> _edit(LabelInfo label) async {
    final edit = await showLabelEditor(context, existing: label);
    if (edit == null) return;
    await _write(
      () => widget.api.patchLabel(label.id, name: edit.name, color: edit.color),
    );
  }

  Future<void> _toggle(LabelInfo label) =>
      _write(() => widget.api.patchLabel(label.id, active: !label.active));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('label-add'),
        onPressed: () => unawaited(_create()),
        icon: const Icon(Icons.add),
        label: Text(l.labelNew),
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.labelsLoadFailed,
        message: '$_error',
        action: OutlinedButton.icon(
          onPressed: () => unawaited(_load()),
          icon: const Icon(Icons.refresh),
          label: Text(l.commonRetry),
        ),
      );
    }
    final org = [
      for (final x in _labels)
        if (x.scope == 'org') x,
    ];
    final mine = [
      for (final x in _labels)
        if (x.scope != 'org') x,
    ];
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Tokens.gap,
        0,
        Tokens.gap,
        96,
      ),
      children: [
        SectionHeader(l.labelsOrgTitle),
        if (org.isEmpty) Text(l.labelsEmpty),
        for (final x in org) _tile(l, x),
        SectionHeader(l.labelsPersonalTitle),
        if (mine.isEmpty) Text(l.labelsEmpty),
        for (final x in mine) _tile(l, x),
      ],
    );
  }

  Widget _tile(AppLocalizations l, LabelInfo label) {
    final editable = _canEdit(label);
    return Card(
      key: ValueKey('label-${label.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: labelColor(label.color),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          label.name,
          style: label.active
              ? null
              : TextStyle(
                  color: Theme.of(context).disabledColor,
                  decoration: TextDecoration.lineThrough,
                ),
        ),
        trailing: editable
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: ValueKey('label-edit-${label.id}'),
                    tooltip: l.labelEdit,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => unawaited(_edit(label)),
                  ),
                  IconButton(
                    key: ValueKey('label-toggle-${label.id}'),
                    tooltip: label.active ? l.labelDeactivate : l.labelActivate,
                    icon: Icon(
                      label.active
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => unawaited(_toggle(label)),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
