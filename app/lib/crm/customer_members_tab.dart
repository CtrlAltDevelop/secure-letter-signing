import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/crm/crm_api.dart';
import 'package:letter_signing/crm/crm_ui.dart';
import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/people_picker.dart';

/// Members of a customer file with their roles. Managers (`can.members`) add, change and
/// remove members; the owner always stays a manager. Each change replaces the whole list.
class CustomerMembersTab extends StatefulWidget {
  const CustomerMembersTab({
    super.key,
    required this.api,
    required this.customer,
    required this.directory,
    required this.onChanged,
  });
  final CrmApi api;
  final Customer customer;
  final Future<List<UserRef>> Function() directory;
  final ValueChanged<Customer> onChanged;

  @override
  State<CustomerMembersTab> createState() => _CustomerMembersTabState();
}

class _CustomerMembersTabState extends State<CustomerMembersTab> {
  bool _busy = false;

  Customer get c => widget.customer;

  Future<void> _save(List<CustomerMember> members) async {
    if (_busy) return;
    final failed = AppLocalizations.of(context).crmSaveFailed;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      widget.onChanged(await widget.api.setMembers(c.id, members));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final dir = await widget.directory();
    if (!mounted) return;
    final current = [for (final m in c.members) m.user.id];
    final picked = await showPeoplePickerSheet(
      context,
      title: l.crmMembersAdd,
      directory: dir,
      selected: current,
    );
    if (picked == null) return;
    final byId = {for (final u in dir) u.id: u};
    await _save([
      for (final m in c.members)
        if (picked.contains(m.user.id) || m.user.id == c.ownerId) m,
      for (final id in picked)
        if (!current.contains(id))
          CustomerMember(
            user: byId[id] ?? UserRef(id: id),
            role: MemberRole.member,
          ),
    ]);
  }

  Future<void> _setRole(CustomerMember m, String role) => _save([
    for (final x in c.members)
      if (x.user.id == m.user.id)
        CustomerMember(user: x.user, role: role)
      else
        x,
  ]);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final edit = c.can.members;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              if (edit)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    key: const ValueKey('crm-member-add'),
                    onPressed: _busy ? null : () => unawaited(_add()),
                    icon: const Icon(Icons.person_add_alt),
                    label: Text(l.crmMembersAdd),
                  ),
                ),
              for (final m in c.members) _row(l, m, edit),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(AppLocalizations l, CustomerMember m, bool edit) {
    final owner = m.user.id == c.ownerId;
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.person_outline),
          const SizedBox(width: 12),
          Expanded(child: Text(m.user.displayName)),
          if (edit && !owner) ...[
            DropdownButton<String>(
              key: ValueKey('crm-role-${m.user.id}'),
              value: m.role,
              underline: const SizedBox.shrink(),
              items: [
                for (final r in MemberRole.all)
                  DropdownMenuItem(
                    value: r,
                    child: Text(memberRoleLabel(l, r)),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (r) => r == null ? null : unawaited(_setRole(m, r)),
            ),
            IconButton(
              key: ValueKey('crm-member-remove-${m.user.id}'),
              tooltip: l.crmMemberRemove,
              icon: const Icon(Icons.close),
              onPressed: _busy
                  ? null
                  : () => unawaited(
                      _save([
                        for (final x in c.members)
                          if (x.user.id != m.user.id) x,
                      ]),
                    ),
            ),
          ] else
            StatusPill(memberRoleLabel(l, m.role)),
        ],
      ),
    );
  }
}
