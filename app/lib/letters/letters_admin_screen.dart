import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Manager view: title and participants only (never bodies). Unlist/relist published letters.
class LettersAdminScreen extends StatefulWidget {
  const LettersAdminScreen({
    super.key,
    required this.env,
    this.embedded = false,
  });
  final LettersEnv env;

  /// True when the app shell supplies the title and the notification bell.
  final bool embedded;

  @override
  State<LettersAdminScreen> createState() => _LettersAdminScreenState();
}

class _LettersAdminScreenState extends State<LettersAdminScreen> {
  List<AdminLetter> _rows = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final rows = await widget.env.api.adminList();
      if (mounted) {
        setState(() {
          _rows = rows;
          _error = null;
          _loading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggle(AdminLetter l) async {
    try {
      await widget.env.api.setUnlisted(l.brief.id, unlisted: !l.brief.unlisted);
      await _load();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _content() {
    if (_loading) return const SkeletonList();
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 48),
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load letters',
            message: '$_error',
            action: OutlinedButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                unawaited(_load());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }
    if (_rows.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 48),
          EmptyState(
            icon: Icons.mail_outline,
            title: 'No letters yet',
            message: 'Titles and participants of every letter show up here.',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: Tokens.gap),
      children: [
        for (final l in _rows)
          Padding(
            key: ValueKey(l.brief.id),
            padding: const EdgeInsets.only(bottom: 12),
            child: _AdminCard(letter: l, onToggle: () => _toggle(l)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : AppBar(title: const Text('All letters (manager)')),
    body: PageBody(
      child: RefreshIndicator(onRefresh: _load, child: _content()),
    ),
  );
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.letter, required this.onToggle});
  final AdminLetter letter;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final b = letter.brief;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${b.no}', style: muted),
              const SizedBox(width: 8),
              StatusChip(b.status),
              if (b.unlisted) ...[
                const SizedBox(width: 8),
                const StatusPill('Unlisted'),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            b.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'By ${letter.creatorEmail}  -  ${fmtDate(b.createdAt)}',
            style: muted,
          ),
          if (letter.participants.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in letter.participants)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: PersonAvatar(p.displayName, size: 20),
                    label: Text('${p.displayName} (${p.role})'),
                  ),
              ],
            ),
          ],
          if (b.status == LetterStatus.published) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  b.unlisted
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                label: Text(b.unlisted ? 'Relist' : 'Unlist'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
