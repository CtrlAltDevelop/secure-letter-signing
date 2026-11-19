import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';

/// Digits, dates and ranges read left to right even inside right-to-left text.
class LtrText extends StatelessWidget {
  const LtrText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(text, style: style),
  );
}

/// Persian digits of a number, grouped by thousands for large values.
String fmtNum(Object? v) {
  final n = v is num ? v : num.tryParse('$v') ?? 0;
  final s = n is int || n == n.roundToDouble()
      ? n.round().toString()
      : n.toStringAsFixed(1);
  return toPersianDigits(
    s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','),
  );
}

int intOf(Object? v) => v is num ? v.toInt() : 0;

/// Jalali date of an ISO string, or [fallback].
String dateOf(Object? iso, [String fallback = '']) {
  final d = iso is String ? DateTime.tryParse(iso) : null;
  return d == null ? fallback : toPersianDigits(formatJalaliDate(d.toLocal()));
}

/// A labelled number in a bordered card.
class StatTile extends StatelessWidget {
  const StatTile(this.label, this.value, {super.key, this.warn = false});
  final String label;
  final Object? value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 150,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LtrText(
              fmtNum(value),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: warn && intOf(value) > 0 ? scheme.error : null,
              ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Stat tiles in a wrapping row.
class StatWrap extends StatelessWidget {
  const StatWrap(this.tiles, {super.key});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: tiles);
}

/// Loads a report once and shows a spinner, the error with a retry, or [builder]'s page.
/// Give it a new `key` to reload (e.g. when the period changes).
class ReportView extends StatefulWidget {
  const ReportView({super.key, required this.load, required this.builder});

  final Future<Map<String, dynamic>> Function() load;
  final Widget Function(BuildContext context, Map<String, dynamic> data)
  builder;

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  late Future<Map<String, dynamic>> _future = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snap) {
      if (snap.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${snap.error}'),
              TextButton(
                onPressed: () => setState(() => _future = widget.load()),
                child: Text(AppLocalizations.of(context).commonRetry),
              ),
            ],
          ),
        );
      }
      if (!snap.hasData)
        return const Center(child: CircularProgressIndicator());
      return widget.builder(context, snap.data!);
    },
  );
}

/// A scrolling page with consistent padding.
class ReportPage extends StatelessWidget {
  const ReportPage({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(12), children: children);
}

/// The person line of `{id, full_name, email}`.
String personName(Object? user) {
  final u = asMap(user);
  final name = asString(u['full_name']);
  return name.isEmpty ? asString(u['email'], '#${u['id']}') : name;
}

/// A dropdown of [options] (`value` to label) with the "all" entry first.
class SortMenu extends StatelessWidget {
  const SortMenu({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButton<String>(
    value: options.containsKey(value) ? value : options.keys.first,
    items: [
      for (final e in options.entries)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}

void fireAndForget(Future<void> f) => unawaited(f);
