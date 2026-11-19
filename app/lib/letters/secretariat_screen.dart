import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_card.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/secretariat_detail_screen.dart';
import 'package:letter_signing/letters/secretariat_form_screen.dart';
import 'package:letter_signing/theme/widgets.dart';

const _yearsShown = 5;

/// The secretariat register (visible to `letter.secretariat` holders): incoming and outgoing
/// entries, filtered by direction, Jalali year and text.
class SecretariatScreen extends StatefulWidget {
  const SecretariatScreen({super.key, required this.env});
  final LettersEnv env;

  @override
  State<SecretariatScreen> createState() => _SecretariatScreenState();
}

class _SecretariatScreenState extends State<SecretariatScreen> {
  List<SecretariatEntry> _rows = const [];
  Object? _error;
  bool _loading = true;
  String _direction = '';
  int? _year;
  String _query = '';
  final _search = TextEditingController();

  LettersEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await env.v2.entries(
        direction: _direction,
        year: _year,
        q: _query,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _error = null;
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

  void _reload(VoidCallback change) {
    setState(() {
      change();
      _loading = true;
    });
    unawaited(_load());
  }

  Future<void> _register() async {
    final saved = await Navigator.of(context).push<SecretariatEntry>(
      MaterialPageRoute(builder: (_) => SecretariatFormScreen(env: env)),
    );
    if (saved != null && mounted) unawaited(_load());
  }

  Future<void> _open(SecretariatEntry e) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SecretariatDetailScreen(env: env, entry: e),
      ),
    );
    if (mounted) unawaited(_load());
  }

  Widget _directionFilter(AppLocalizations l) => SegmentedButton<String>(
    showSelectedIcon: false,
    segments: [
      ButtonSegment(value: '', label: Text(l.secretariatAll)),
      ButtonSegment(value: 'in', label: Text(l.secretariatIn)),
      ButtonSegment(value: 'out', label: Text(l.secretariatOut)),
    ],
    selected: {_direction},
    onSelectionChanged: (v) => _reload(() => _direction = v.first),
  );

  Widget _yearFilter(AppLocalizations l) {
    final current = toJalali(DateTime.now()).year;
    return DropdownButton<int?>(
      value: _year,
      underline: const SizedBox.shrink(),
      items: [
        DropdownMenuItem(value: null, child: Text(l.secretariatAnyYear)),
        for (var y = current; y > current - _yearsShown; y--)
          DropdownMenuItem(value: y, child: Text(toPersianDigits(y))),
      ],
      onChanged: (v) => _reload(() => _year = v),
    );
  }

  Widget _filters(AppLocalizations l) => Column(
    children: [
      TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: l.secretariatSearchHint,
        ),
        onSubmitted: (v) => _reload(() => _query = v.trim()),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _directionFilter(l)),
          const SizedBox(width: 8),
          _yearFilter(l),
        ],
      ),
    ],
  );

  Widget _body(AppLocalizations l) {
    if (_loading) return const SkeletonList();
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.secretariatLoadFailed,
        message: '$_error',
        action: OutlinedButton.icon(
          onPressed: () => _reload(() {}),
          icon: const Icon(Icons.refresh),
          label: Text(l.commonRetry),
        ),
      );
    }
    if (_rows.isEmpty) {
      return EmptyState(icon: Icons.inbox_outlined, title: l.secretariatEmpty);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final e in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _EntryCard(entry: e, onTap: () => unawaited(_open(e))),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.lettersSecretariat)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _register,
        icon: const Icon(Icons.add),
        label: Text(l.secretariatRegister),
      ),
      body: PageBody(
        child: Column(
          children: [
            _filters(l),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(onRefresh: _load, child: _body(l)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});
  final SecretariatEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final e = entry;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              NumberLabelChip(e.number),
              StatusPill(
                e.isIncoming ? l.secretariatIn : l.secretariatOut,
                tone: e.isIncoming ? Tone.info : Tone.ok,
              ),
              if (e.registeredAt != null)
                Text(fmtDate(e.registeredAt!), style: muted),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            e.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (e.partyName.isNotEmpty)
            Text(
              '${e.isIncoming ? l.secretariatFrom : l.secretariatTo}: ${e.partyName}',
              style: muted,
            ),
        ],
      ),
    );
  }
}
