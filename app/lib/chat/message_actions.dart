import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/chat_sheets.dart';
import 'package:letter_signing/chat/conversation_controller.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/tasks/task_detail_screen.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome;

const _taskTitleChars = 80;

enum _Act { reply, copy, edit, pin, bookmark, toTask, seen, delete }

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
          if (mine && message.kind == 'text' && message.text.isNotEmpty)
            _tile(ctx, Icons.edit_outlined, l.chatEdit, _Act.edit),
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
    case _Act.edit:
      final text = await _askText(
        context,
        title: l.chatEdit,
        initial: message.text,
        action: l.chatEditSave,
        maxLines: 5,
      );
      if (text != null && text != message.text && context.mounted) {
        await _report(context, controller.edit(message, text));
      }
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

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String initial,
  required String action,
  int maxLines = 1,
}) {
  final l = AppLocalizations.of(context);
  final field = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const ValueKey('chat-text-dialog'),
        controller: field,
        autofocus: true,
        minLines: 1,
        maxLines: maxLines,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('chat-text-dialog-ok'),
          onPressed: () {
            final t = field.text.trim();
            Navigator.pop(ctx, t.isEmpty ? null : t);
          },
          child: Text(action),
        ),
      ],
    ),
  );
}

/// Asks for the task title (prefilled from the message), creates the task through the
/// server's message-to-task endpoint (which also links it back into the chat) and opens it.
/// Inside a project chat the task starts in that project.
Future<void> _toTask(
  BuildContext context,
  ChatEnv env,
  Conversation conv,
  ChatMessage m,
) async {
  final l = AppLocalizations.of(context);
  final flat = m.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final title = flat.length <= _taskTitleChars
      ? flat
      : '${flat.substring(0, _taskTitleChars - 1)}…';
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final chosen = await _askText(
    context,
    title: l.chatToTaskTitle,
    initial: title,
    action: l.chatToTaskCreate,
  );
  if (chosen == null) return;
  try {
    final id = await env.api.toTask(
      m.id,
      title: chosen,
      projectId: conv.projectId,
    );
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(env: env.tasks, taskId: id),
      ),
    );
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l.chatActionFailed)));
  }
}
