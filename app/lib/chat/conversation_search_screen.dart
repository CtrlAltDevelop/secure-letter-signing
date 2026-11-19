import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';

/// Text search inside one conversation; popping returns the tapped message.
class ConversationSearchScreen extends StatefulWidget {
  const ConversationSearchScreen({
    super.key,
    required this.env,
    required this.conversationId,
  });
  final ChatEnv env;
  final String conversationId;

  @override
  State<ConversationSearchScreen> createState() =>
      _ConversationSearchScreenState();
}

class _ConversationSearchScreenState extends State<ConversationSearchScreen> {
  List<ChatMessage> _hits = const [];
  bool _searched = false;
  bool _loading = false;
  Object? _error;

  Future<void> _run(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.env.api.search(
        query,
        conversation: widget.conversationId,
      );
      if (mounted) {
        setState(() {
          _hits = rows;
          _searched = true;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey('chat-search-field'),
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: l.chatSearchHint,
          ),
          onSubmitted: (q) => unawaited(_run(q)),
        ),
      ),
      body: _body(l),
    );
  }

  Widget _body(AppLocalizations l) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('$_error'));
    if (_searched && _hits.isEmpty) {
      return Center(child: Text(l.chatSearchNoResults));
    }
    return ListView(
      children: [
        for (final m in _hits)
          ListTile(
            key: ValueKey('chat-hit-${m.id}'),
            title: Text(m.text, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(m.author.displayName),
            onTap: () => Navigator.pop(context, m),
          ),
      ],
    );
  }
}
