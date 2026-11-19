import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show outcomeOf, ActionOutcome;
import 'package:letter_signing/workspace/widgets/people_picker.dart';

/// Create a group or a channel (needs `chat.create_group`). Pops with the new [Conversation].
class CreateConversationScreen extends StatefulWidget {
  const CreateConversationScreen({
    super.key,
    required this.env,
    required this.kind,
  });
  final ChatEnv env;

  /// [ConvKind.group] or [ConvKind.channel].
  final String kind;

  @override
  State<CreateConversationScreen> createState() =>
      _CreateConversationScreenState();
}

class _CreateConversationScreenState extends State<CreateConversationScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _public = false;
  late String _policy = widget.kind == ConvKind.channel ? 'admins' : 'all';
  List<int> _members = const [];
  List<UserRef> _directory = const [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.env.directory().then((d) {
        if (mounted) setState(() => _directory = d);
      }),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = l.chatNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final c = await widget.env.api.create(
        kind: widget.kind,
        name: _name.text.trim(),
        description: _description.text.trim(),
        isPublic: _public,
        memberIds: _members,
        postPolicy: _policy,
      );
      if (mounted) Navigator.of(context).pop(c);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = outcomeOf(e) == ActionOutcome.forbidden
            ? l.chatCreateForbidden
            : l.chatActionFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final channel = widget.kind == ConvKind.channel;
    return Scaffold(
      appBar: AppBar(
        title: Text(channel ? l.chatNewChannel : l.chatNewGroup),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => unawaited(_save()),
            child: Text(l.chatCreate),
          ),
        ],
      ),
      body: PageBody(
        child: ListView(
          children: [
            TextField(
              controller: _name,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: l.chatName,
                errorText: _error,
              ),
            ),
            TextField(
              controller: _description,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(labelText: l.chatDescription),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.chatPublicSwitch),
              value: _public,
              onChanged: (v) => setState(() => _public = v),
            ),
            Text(
              l.chatPostPolicy,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'all', label: Text(l.chatPostAll)),
                ButtonSegment(value: 'admins', label: Text(l.chatPostAdmins)),
              ],
              selected: {_policy},
              onSelectionChanged: (s) => setState(() => _policy = s.first),
            ),
            const SizedBox(height: 12),
            PeoplePicker(
              label: l.chatMembers,
              directory: _directory,
              selectedIds: _members,
              onChanged: (ids) => setState(() => _members = ids),
            ),
          ],
        ),
      ),
    );
  }
}
