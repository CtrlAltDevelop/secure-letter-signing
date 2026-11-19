import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/chat_api.dart';
import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/conversation_controller.dart';
import 'package:letter_signing/chat/conversation_info_sheet.dart';
import 'package:letter_signing/chat/conversation_view.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/jalali/jalali_picker.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show SkeletonList;
import 'package:letter_signing/theme/widgets.dart';

/// A chat embedded in another screen (project tab, customer file tab): resolves the mirrored
/// conversation first, then shows it with a small toolbar (jump to a date, details).
class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.env, required this.resolve});
  final ChatEnv env;

  /// `GET /projects/{id}/chat` or `GET /customers/{id}/chat`.
  final Future<Conversation> Function(ChatApi api) resolve;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  ConversationController? _c;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conv = await widget.resolve(widget.env.api);
      final c = ConversationController(
        api: widget.env.api,
        live: widget.env.live,
        userId: widget.env.userId,
        conversationId: conv.id,
        initial: conv,
      );
      unawaited(c.load());
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _c = c;
        _loading = false;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
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
    if (day != null && !await _c!.jumpToDate(day)) {
      messenger.showSnackBar(SnackBar(content: Text(l.chatNoMessagesOnDate)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = _c;
    if (_loading) return const SkeletonList(count: 4);
    if (c == null) {
      return EmptyState(
        icon: Icons.chat_bubble_outline,
        title: l.chatLoadFailed,
        message: '${_error ?? ''}',
        action: OutlinedButton.icon(
          onPressed: () => unawaited(_resolve()),
          icon: const Icon(Icons.refresh),
          label: Text(l.commonRetry),
        ),
      );
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: l.chatJumpToDate,
              icon: const Icon(Icons.event),
              onPressed: () => unawaited(_jump()),
            ),
            IconButton(
              tooltip: l.chatInfo,
              icon: const Icon(Icons.info_outline),
              onPressed: () => unawaited(
                showConversationInfo(context, env: widget.env, controller: c),
              ),
            ),
          ],
        ),
        Expanded(
          child: ConversationView(env: widget.env, controller: c),
        ),
      ],
    );
  }
}

/// The Chat tab of a project.
class ProjectChatTab extends StatelessWidget {
  const ProjectChatTab({super.key, required this.env, required this.projectId});
  final ChatEnv env;
  final String projectId;

  @override
  Widget build(BuildContext context) => ChatPanel(
    key: ValueKey(projectId),
    env: env,
    resolve: (api) => api.projectChat(projectId),
  );
}

/// The Chat tab of a customer file (the CRM screens embed this).
class CustomerChatTab extends StatelessWidget {
  const CustomerChatTab({
    super.key,
    required this.env,
    required this.customerId,
  });
  final ChatEnv env;
  final String customerId;

  @override
  Widget build(BuildContext context) => ChatPanel(
    key: ValueKey(customerId),
    env: env,
    resolve: (api) => api.customerChat(customerId),
  );
}
