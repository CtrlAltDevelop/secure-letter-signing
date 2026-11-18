import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/paper_preview.dart';
import 'package:letter_signing/letters/paper_screen.dart';

const double _wideBreakpoint = 900;

/// Write the letter like the original HTML app: an edit pane and a live A4 preview.
/// Wide screens show both side by side, phones switch with Edit / Preview tabs. Pops the text.
class PaperEditorScreen extends StatefulWidget {
  const PaperEditorScreen({
    super.key,
    required this.head,
    required this.title,
    required this.initialText,
    this.number = '(new)',
    this.date = '',
  });
  final Letterhead head;
  final String title;
  final String initialText;
  final String number;
  final String date;

  @override
  State<PaperEditorScreen> createState() => _PaperEditorScreenState();
}

class _PaperEditorScreenState extends State<PaperEditorScreen> {
  late final _text = TextEditingController(text: widget.initialText);
  final _preview = GlobalKey<PaperPreviewState>();
  double _font = defaultPaperFont;
  bool _showPreview = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _print() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _preview.currentState?.print();
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Could not print: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PaperDocument get _doc => PaperDocument(
    head: widget.head,
    title: widget.title,
    number: widget.number,
    date: widget.date.isEmpty ? _today() : widget.date,
    text: _text.text,
  );

  static String _today() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }

  Widget _editPane(BuildContext context) => Card(
    margin: const EdgeInsets.all(12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Letter text', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _text,
              autofocus: true,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Write the letter here...',
                alignLabelWithHint: true,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _previewPane() =>
      PaperPreview(key: _preview, doc: _doc, fontSize: _font);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_text.text);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Write on paper'),
          actions: [
            if (wide || _showPreview)
              PrintButton(busy: _busy, onPressed: () => unawaited(_print())),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_text.text),
              child: const Text('Done'),
            ),
          ],
        ),
        body: Column(
          children: [
            if (!wide)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Edit')),
                    ButtonSegment(value: true, label: Text('Preview')),
                  ],
                  selected: {_showPreview},
                  onSelectionChanged: (v) =>
                      setState(() => _showPreview = v.first),
                ),
              ),
            if (wide || _showPreview)
              PaperFontSlider(
                value: _font,
                label: 'A4',
                onChanged: (v) => setState(() => _font = v),
              ),
            if (_error != null) ErrorBanner(_error!),
            Expanded(
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: _editPane(context)),
                        Expanded(child: _previewPane()),
                      ],
                    )
                  : (_showPreview ? _previewPane() : _editPane(context)),
            ),
          ],
        ),
      ),
    );
  }
}
