import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/conversation_screen.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/workspace/open_target.dart';

/// Opens search hits, bookmarks and pins of the `chat` module: `conversation` targets carry the
/// conversation id; `message` and pinned `subject` targets only the conversation's subject id,
/// which is matched against my conversation list. False when nothing matches.
TargetOpener chatOpener(ChatEnv env) => (context, target) async {
  var id = target.kind == 'conversation' ? target.id : null;
  if (id == null && target.subjectId.isNotEmpty) {
    final mine = await env.api.conversations(const ConvFilter());
    for (final c in mine) {
      if (c.subjectId == target.subjectId) id = c.id;
    }
  }
  if (id == null || !context.mounted) return false;
  final convId = id;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ConversationScreen(env: env, conversationId: convId),
    ),
  );
  return true;
};
