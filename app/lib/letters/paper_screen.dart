import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/paper_preview.dart';

const double _minFont = 9;
const double _maxFont = 20;
const double defaultPaperFont = 12;

/// The letter as it will look on A4 paper: letterhead, adjustable font size, print / save PDF.
class PaperScreen extends StatefulWidget {
  const PaperScreen({
    super.key,
    required this.doc,
    this.initialFont = defaultPaperFont,
  });
  final PaperDocument doc;
  final double initialFont;

  @override
  State<PaperScreen> createState() => _PaperScreenState();
}

class _PaperScreenState extends State<PaperScreen> {
  late double _font = widget.initialFont;
  final _preview = GlobalKey<PaperPreviewState>();
  bool _busy = false;
  String? _error;

  Future<void> _print() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _preview.currentState?.print();
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context).paperPrintFailed('$e'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppLocalizations.of(context).paperPreviewTitle),
      actions: [PrintButton(busy: _busy, onPressed: () => unawaited(_print()))],
    ),
    body: Column(
      children: [
        PaperFontSlider(
          value: _font,
          label: 'A4',
          onChanged: (v) => setState(() => _font = v),
        ),
        if (_error != null) ErrorBanner(_error!),
        Expanded(
          child: PaperPreview(key: _preview, doc: widget.doc, fontSize: _font),
        ),
      ],
    ),
  );
}

class PrintButton extends StatelessWidget {
  const PrintButton({super.key, required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).paperPrint,
    onPressed: busy ? null : onPressed,
    icon: busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.print_outlined),
  );
}

class PaperFontSlider extends StatelessWidget {
  const PaperFontSlider({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });
  final double value;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        const Icon(Icons.text_fields, size: 18),
        Expanded(
          child: Slider(
            min: _minFont,
            max: _maxFont,
            divisions: (_maxFont - _minFont).round(),
            value: value,
            label: '${value.round()} pt',
            onChanged: onChanged,
          ),
        ),
        Text('${value.round()} pt  |  $label'),
      ],
    ),
  );
}
