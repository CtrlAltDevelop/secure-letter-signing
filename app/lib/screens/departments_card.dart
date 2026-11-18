import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/screens/auth_screens.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Manager: create, rename and deactivate departments (nothing is deleted).
class DepartmentsCard extends StatefulWidget {
  const DepartmentsCard({super.key, required this.api, this.onChanged});
  final ApiClient api;

  /// Called after any change so the people list can refresh its department labels.
  final VoidCallback? onChanged;

  @override
  State<DepartmentsCard> createState() => _DepartmentsCardState();
}

class _DepartmentsCardState extends State<DepartmentsCard> {
  late Future<List<Map<String, dynamic>>> _items = _load();

  Future<List<Map<String, dynamic>>> _load() async => List.from(
    (await widget.api.call('GET', '/manage/departments') as List).map(
      (e) => Map<String, dynamic>.from(e as Map),
    ),
  );

  Future<void> _call(String method, String path, Object body) async {
    final ok = await runGuarded(
      context,
      () => widget.api.call(method, path, body: body),
    );
    if (!ok || !mounted) return;
    setState(() => _items = _load());
    widget.onChanged?.call();
  }

  Future<void> _edit([Map<String, dynamic>? dept]) async {
    final name = TextEditingController(text: '${dept?['name'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dept == null ? 'New department' : 'Rename department'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: name,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final text = name.text.trim();
    name.dispose();
    if (ok != true || text.isEmpty) return;
    if (dept == null) {
      await _call('POST', '/manage/departments', {'name': text});
    } else {
      await _call('PATCH', '/manage/departments/${dept['id']}', {'name': text});
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(
        'Departments',
        subtitle: 'Only the manager can change these',
        trailing: FilledButton.tonalIcon(
          onPressed: _edit,
          icon: const Icon(Icons.add),
          label: const Text('New'),
        ),
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _items,
        builder: (context, snap) {
          if (snap.hasError) return AppCard(child: Text('${snap.error}'));
          final items = snap.data;
          if (items == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const AppCard(child: Text('No departments yet'));
          }
          return Column(
            children: [
              for (final d in items) ...[
                AppCard(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Opacity(
                    opacity: d['active'] == true ? 1 : 0.55,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${d['name']}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                '${d['members']} people'
                                '${d['active'] == true ? '' : '  -  inactive'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Rename',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(d),
                        ),
                        TextButton(
                          onPressed: () => _call(
                            'PATCH',
                            '/manage/departments/${d['id']}',
                            {'active': d['active'] != true},
                          ),
                          child: Text(
                            d['active'] == true ? 'Deactivate' : 'Reactivate',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    ],
  );
}

/// Dialog to set one person's department; returns true when it changed.
Future<bool> pickDepartment(
  BuildContext context,
  ApiClient api,
  UserInfo user,
) async {
  final all = (await api.call('GET', '/manage/departments') as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .where((d) => d['active'] == true)
      .toList();
  if (!context.mounted) return false;
  int? chosen = user.departmentId;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Department'),
        content: SizedBox(
          width: 320,
          child: DropdownButtonFormField<int?>(
            initialValue: all.any((d) => d['id'] == chosen) ? chosen : null,
            decoration: InputDecoration(labelText: user.email),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('None')),
              for (final d in all)
                DropdownMenuItem<int?>(
                  value: d['id'] as int,
                  child: Text('${d['name']}'),
                ),
            ],
            onChanged: (v) => setLocal(() => chosen = v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return false;
  return runGuarded(
    context,
    () => api.call(
      'PUT',
      '/manage/users/${user.id}/department',
      body: {'department_id': chosen},
    ),
  );
}
