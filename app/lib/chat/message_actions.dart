import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/chat_sheets.dart';
import 'package:letter_signing/chat/conversation_controller.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/tasks/models.dart' show TaskDraft;
import 'package:letter_signing/tasks/task_form_screen.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome;

const _taskTitleChars = 80;

enum _Act { reply, copy, pin, bookmark, toTask, seen, delete }

/// The long-press menu of a message: reply, copy, pin, bookmark, turn into a task, who saw it,
/// delete. Entries follow what the caller may do (the server stays the judge).
Future<void> showMessageActions(
  BuildContext context, {
  required ChatEnv env,
  required ConversationController controller,
  required ChatMessage message,
}) async {
  if (message.deleted || message.isSystem) return;
  final l = AppLocalizations.of(context);
  final conv = controller.conversation;
  if (conv == null) return;
  final mine = message.author.id == env.userId;
  final moderator = conv.canAdmin || conv.myRole == 'admin';
  final canPin = conv.isDm || moderator;
  final act = await showModalBottomSheet<_Act>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.canPost)
            _tile(ctx, Icons.reply, l.chatReply, _Act.reply),
          if (message.text.isNotEmpty)
            _tile(ctx, Icons.copy, l.chatCopy, _Act.copy),
          if (canPin)
            _tile(
              ctx,
              Icons.push_pin_outlined,
              message.pinned ? l.chatUnpinMessage : l.chatPinMessage,
              _Act.pin,
            ),
          _tile(ctx, Icons.bookmark_border, l.chatBookmark, _Act.bookmark),
          if (env.tasks.canCreate && message.text.isNotEmpty)
            _tile(ctx, Icons.add_task, l.chatToTask, _Act.toTask),
          if (mine || moderator)
            _tile(ctx, Icons.done_all, l.chatSeenBy, _Act.seen),
          if (mine || moderator)
            _tile(ctx, Icons.delete_outline, l.chatDelete, _Act.delete),
        ],
      ),
    ),
  );
  if (act == null || !context.mounted) return;
  switch (act) {
    case _Act.reply:
      controller.setReplyTo(message);
    case _Act.copy:
      await Clipboard.setData(ClipboardData(text: message.text));
    case _Act.pin:
      await _report(
        context,
        controller.setMessagePinned(message, pinned: !message.pinned),
      );
    case _Act.bookmark:
      await _report(
        context,
        controller.bookmark(message),
        success: l.chatBookmarked,
      );
    case _Act.toTask:
      await _toTask(context, env, conv, message);
    case _Act.seen:
      await showChatSeenSheet(context, () => controller.seen(message));
    case _Act.delete:
      if (await _confirmDelete(context)) {
        if (context.mounted) {
          await _report(context, controller.delete(message));
        }
      }
  }
}

Widget _tile(BuildContext ctx, IconData icon, String label, _Act act) =>
    ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.pop(ctx, act),
    );

Future<bool> _confirmDelete(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(l.chatDeleteConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.chatDelete),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<void> _report(
  BuildContext context,
  Future<ActionOutcome> run, {
  String? success,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final out = await run;
  final text = switch (out) {
    ActionOutcome.ok => success,
    ActionOutcome.forbidden => l.chatForbidden,
    _ => l.chatActionFailed,
  };
  if (text != null) messenger.showSnackBar(SnackBar(content: Text(text)));
}

/// Opens the task form prefilled from the message (inside a project chat the task starts in
/// that project), exactly like "create task" on a letter.
Future<void> _toTask(
  BuildContext context,
  ChatEnv env,
  Conversation conv,
  ChatMessage m,
) async {
  final flat = m.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final title = flat.length <= _taskTitleChars
      ? flat
      : '${flat.substring(0, _taskTitleChars - 1)}…';
  await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder: (_) => TaskFormScreen(
        env: env.tasks,
        initialProjectId: conv.projectId,
        initialDraft: TaskDraft(title: title, description: m.text),
      ),
    ),
  );
}
