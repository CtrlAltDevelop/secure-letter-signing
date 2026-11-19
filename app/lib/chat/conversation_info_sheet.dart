import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/conversation_controller.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/jalali/jalali_format.dart' show toPersianDigits;
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/polls/polls_env.dart';
import 'package:letter_signing/polls/polls_section.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome, outcomeOf;
import 'package:letter_signing/workspace/widgets/people_picker.dart';

/// Details of a conversation: members, pin and mute for me, add members (admins), leave.
/// Pops `true` when the user left (the screen closes).
Future<bool?> showConversationInfo(
  BuildContext context, {
  required ChatEnv env,
  required ConversationController controller,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _InfoSheet(env: env, controller: controller),
);

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({required this.env, required this.controller});
  final ChatEnv env;
  final ConversationController controller;

  Future<void> _run(
    BuildContext context,
    Future<Object?> Function() action,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      await controller.reloadConversation();
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            outcomeOf(e) == ActionOutcome.forbidden
                ? l.chatForbidden
                : l.chatActionFailed,
          ),
        ),
      );
    }
  }

  Future<void> _leave(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.chatLeaveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.chatLeave),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, () => env.api.leave(controller.conversationId));
    if (context.mounted) Navigator.pop(context, true);
  }

  Future<void> _addMembers(BuildContext context, Conversation c) async {
    final l = AppLocalizations.of(context);
    final dir = await env.directory();
    if (!context.mounted) return;
    final current = c.members ?? const <ChatMember>[];
    final picked = await showPeoplePickerSheet(
      context,
      title: l.chatAddMembers,
      directory: dir,
      selected: [for (final m in current) m.user.id],
    );
    if (picked == null || !context.mounted) return;
    final roles = {for (final m in current) m.user.id: m.role};
    await _run(
      context,
      () => env.api.setMembers(c.id, [
        for (final id in picked) (userId: id, role: roles[id] ?? 'member'),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller.conversation;
        if (c == null) return const SizedBox.shrink();
        final editable = c.canAdmin && !c.isDm && !c.isMirrored;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
              children: [
                Text(
                  c.isDm ? (c.otherUser?.displayName ?? c.name) : c.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (c.description.isNotEmpty) Text(c.description),
                if (c.isMember) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.chatPinConv),
                    value: c.pinned,
                    onChanged: (v) => unawaited(
                      _run(
                        context,
                        () => env.api.pinConversation(c.id, pinned: v),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.chatMute),
                    value: c.muted,
                    onChanged: (v) => unawaited(
                      _run(context, () => env.api.mute(c.id, muted: v)),
                    ),
                  ),
                ],
                ListTile(
                  key: const ValueKey('chat-polls'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.poll_outlined),
                  title: Text(l.pollsTitle),
                  onTap: () => unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => PollsScreen(
                          env: PollsEnv.of(
                            env.tasks.api.workspace,
                            env.live,
                            env.userId,
                          ),
                          targetSubjectId: c.subjectId,
                        ),
                      ),
                    ),
                  ),
                ),
                if (c.members != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l.chatMembers} (${toPersianDigits(c.members!.length)})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (editable)
                        TextButton.icon(
                          onPressed: () => unawaited(_addMembers(context, c)),
                          icon: const Icon(Icons.person_add_alt),
                          label: Text(l.chatAddMembers),
                        ),
                    ],
                  ),
                  for (final m in c.members!)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(
                        fullName: m.user.fullName,
                        email: m.user.email,
                        radius: 16,
                      ),
                      title: Text(m.user.displayName),
                      trailing: m.isAdmin ? Text(l.chatAdminRole) : null,
                    ),
                ],
                if (c.isMember && !c.isDm && !c.isMirrored)
                  TextButton.icon(
                    onPressed: () => unawaited(_leave(context)),
                    icon: const Icon(Icons.logout),
                    label: Text(l.chatLeave),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
