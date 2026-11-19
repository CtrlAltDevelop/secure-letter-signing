import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';

typedef PostComment = Future<bool> Function(
  String text, {
  int? parentId,
  required String kind,
  int? progress,
});

/// Comments of a subject, threaded one level (replies sit under their parent), with a
/// composer for new comments, replies, optional progress reports and editing one's own.
class CommentThread extends StatefulWidget {
  const CommentThread({
    super.key,
    required this.comments,
    required this.currentUserId,
    required this.onPost,
    required this.onEdit,
    required this.onDelete,
    this.canComment = true,
    this.allowReports = false,
  });

  /// Null while loading.
  final List<CommentInfo>? comments;
  final int currentUserId;
  final PostComment onPost;
  final Future<bool> Function(int id, String text) onEdit;
  final Future<bool> Function(int id) onDelete;
  final bool canComment;
  final bool allowReports;

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  final _text = TextEditingController();
  CommentInfo? _replyTo;
  CommentInfo? _editing;
  bool _report = false;
  bool _withProgress = false;
  double _progress = 50;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _reset() {
    _text.clear();
    _replyTo = null;
    _editing = null;
    _report = false;
    _withProgress = false;
  }

  Future<void> _submit() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final editing = _editing;
    final ok = editing != null
        ? await widget.onEdit(editing.id, text)
        : await widget.onPost(
            text,
            parentId: _replyTo?.id,
            kind: _report ? CommentInfo.reportKind : CommentInfo.commentKind,
            progress: _report && _withProgress ? _progress.round() : null,
          );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) _reset();
    });
  }

  void _startReply(CommentInfo c) => setState(() {
    _reset();
    _replyTo = c;
  });

  void _startEdit(CommentInfo c) => setState(() {
    _reset();
    _editing = c;
    _text.text = c.text;
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final all = widget.comments;
    if (all == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final top = [
      for (final c in all)
        if (c.parentId == null) c,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (top.isEmpty)
          EmptyState(icon: Icons.chat_bubble_outline, title: l.commentsEmpty),
        for (final c in top) ...[
          _row(c, depth: 0),
          for (final r in all.where((x) => x.parentId == c.id))
            _row(r, depth: 1),
        ],
        if (widget.canComment) ...[const SizedBox(height: 8), _composer(l)],
      ],
    );
  }

  Widget _row(CommentInfo c, {required int depth}) => Padding(
    key: ValueKey('comment-${c.id}'),
    padding: EdgeInsetsDirectional.only(start: 28.0 * depth, bottom: 8),
    child: _CommentCard(
      comment: c,
      mine: c.author.id == widget.currentUserId,
      canReply: widget.canComment && depth == 0,
      onReply: () => _startReply(c),
      onEdit: () => _startEdit(c),
      onDelete: () => unawaited(widget.onDelete(c.id)),
    ),
  );

  Widget _composer(AppLocalizations l) {
    final scheme = Theme.of(context).colorScheme;
    final banner = _editing != null
        ? l.commentEditing
        : _replyTo != null
        ? l.commentReplyingTo(_replyTo!.author.displayName)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banner != null)
          Row(
            children: [
              Expanded(
                child: Text(banner, style: TextStyle(color: scheme.primary)),
              ),
              TextButton(
                onPressed: () => setState(_reset),
                child: Text(l.commonCancel),
              ),
            ],
          ),
        if (widget.allowReports && _editing == null) _kindChoice(l),
        if (_report && _editing == null) _progressChoice(l),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(hintText: l.commentHint),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: _editing != null ? l.commonSave : l.commentSend,
              onPressed: _sending ? null : () => unawaited(_submit()),
              icon: Icon(_editing != null ? Icons.check : Icons.send),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kindChoice(AppLocalizations l) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: Text(l.commentKindComment),
          selected: !_report,
          onSelected: (_) => setState(() => _report = false),
        ),
        ChoiceChip(
          label: Text(l.commentKindReport),
          selected: _report,
          onSelected: (_) => setState(() => _report = true),
        ),
      ],
    ),
  );

  Widget _progressChoice(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _withProgress,
        title: Text(l.commentAttachProgress),
        onChanged: (v) => setState(() => _withProgress = v ?? false),
      ),
      if (_withProgress)
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _progress,
                max: 100,
                divisions: 20,
                onChanged: (v) => setState(() => _progress = v),
              ),
            ),
            Text(toPersianDigits('${_progress.round()}٪')),
          ],
        ),
    ],
  );
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.mine,
    required this.canReply,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  final CommentInfo comment;
  final bool mine;
  final bool canReply;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final c = comment;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                fullName: c.author.fullName,
                email: c.author.email,
                radius: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.author.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (c.isReport) StatusPill(l.commentKindReport, tone: Tone.info),
            ],
          ),
          const SizedBox(height: 6),
          Text(c.text),
          if (c.progress != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.commentProgress(toPersianDigits(c.progress!)),
                style: muted,
              ),
            ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              if (c.createdAt != null)
                Text(formatRelative(c.createdAt!), style: muted),
              if (c.edited) Text('· ${l.commentEdited}', style: muted),
              if (canReply)
                TextButton(onPressed: onReply, child: Text(l.commentReply)),
              if (mine) ...[
                TextButton(onPressed: onEdit, child: Text(l.commentEdit)),
                TextButton(onPressed: onDelete, child: Text(l.commentDelete)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
