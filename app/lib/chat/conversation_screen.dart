import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/conversation_controller.dart';
import 'package:letter_signing/chat/conversation_info_sheet.dart';
import 'package:letter_signing/chat/conversation_view.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/jalali/jalali_picker.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/app_theme.dart' show Tokens;

/// One conversation as a full screen. [initial] (from the list) shows the title at once.
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.env,
    required this.conversationId,
    this.initial,
  });
  final ChatEnv env;
  final String conversationId;
  final Conversation? initial;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late final ConversationController _c = ConversationController(
    api: widget.env.api,
    live: widget.env.live,
    userId: widget.env.userId,
    conversationId: widget.conversationId,
    initial: widget.initial,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_c.load());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _jump() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final day = await showJalaliDatePicker(
      context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (day == null) return;
    if (!await _c.jumpToDate(day)) {
      messenger.showSnackBar(SnackBar(content: Text(l.chatNoMessagesOnDate)));
    }
  }

  Future<void> _info() async {
    final left = await showConversationInfo(
      context,
      env: widget.env,
      controller: _c,
    );
    if (left == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final c = _c.conversation;
        final title = c == null
            ? ''
            : (c.isDm ? (c.otherUser?.displayName ?? c.name) : c.name);
        return Scaffold(
          appBar: AppBar(
            title: Text(title, overflow: TextOverflow.ellipsis),
            actions: [
              if (c?.isMember ?? false)
                IconButton(
                  tooltip: l.chatJumpToDate,
                  icon: const Icon(Icons.event),
                  onPressed: () => unawaited(_jump()),
                ),
              if (c != null)
                IconButton(
                  tooltip: l.chatInfo,
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => unawaited(_info()),
                ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Tokens.maxContentWidth,
              ),
              child: ConversationView(env: widget.env, controller: _c),
            ),
          ),
        );
      },
    );
  }
}
