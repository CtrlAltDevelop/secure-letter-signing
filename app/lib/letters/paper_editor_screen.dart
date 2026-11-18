import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/paper_preview.dart';
import 'package:letter_signing/letters/paper_screen.dart';
import 'package:letter_signing/letters/rich/rich_controller.dart';
import 'package:letter_signing/letters/rich/rich_doc.dart';
import 'package:letter_signing/letters/rich/rich_layout.dart';

const double _wideBreakpoint = 900;
const _swatch = [
  Color(0xFF081528),
  Color(0xFF165EF6),
  Color(0xFFB3261E),
  Color(0xFF1F8F78),
];
const _swatchNames = ['Ink', 'Blue', 'Red', 'Green'];

/// Write the letter like the original HTML app: an edit pane and a live A4 preview.
/// Wide screens show both side by side, phones switch with Edit / Preview tabs. Pops the text.
class PaperEditorScreen extends StatefulWidget {
  const PaperEditorScreen({
    super.key,
    required this.head,
    required this.title,
    required this.initial,
    this.number = '(new)',
    this.date = '',
  });
  final Letterhead head;
  final String title;
  final RichDoc initial;
  final String number;
  final String date;

  @override
  State<PaperEditorScreen> createState() => _PaperEditorScreenState();
}

class _PaperEditorScreenState extends State<PaperEditorScreen> {
  late final _text = RichController(widget.initial)..addListener(_changed);
  final _preview = GlobalKey<PaperPreviewState>();
  double _font = defaultPaperFont;
  bool _showPreview = false;
  bool _busy = false;
  String? _error;

  void _changed() {
    if (mounted) setState(() {});
  }

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
    text: _text.doc,
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
          _toolbar(),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _text,
              autofocus: true,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Write the letter here...',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _status(context),
        ],
      ),
    ),
  );

  Widget _status(BuildContext context) {
    final pages = paginateRich(_text.doc, _font).length;
    return Text(
      '${_text.doc.wordCount} words  |  ${_text.text.length} characters  |  '
      '$pages A4 page${pages == 1 ? '' : 's'} at ${_font.round()} pt',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  Widget _toolbar() {
    final flags = _text.activeFlags;
    final para = _text.currentPara;
    Widget tool(
      IconData icon,
      String tip,
      VoidCallback? onTap, {
      bool on = false,
    }) => IconButton(
      tooltip: tip,
      isSelected: on,
      onPressed: onTap,
      icon: Icon(icon),
      visualDensity: VisualDensity.compact,
    );
    return Wrap(
      children: [
        tool(Icons.undo, 'Undo', _text.canUndo ? _text.undo : null),
        tool(Icons.redo, 'Redo', _text.canRedo ? _text.redo : null),
        tool(
          Icons.format_bold,
          'Bold',
          () => _text.toggle(flagBold),
          on: flags & flagBold != 0,
        ),
        tool(
          Icons.format_italic,
          'Italic',
          () => _text.toggle(flagItalic),
          on: flags & flagItalic != 0,
        ),
        tool(
          Icons.format_underlined,
          'Underline',
          () => _text.toggle(flagUnderline),
          on: flags & flagUnderline != 0,
        ),
        tool(
          Icons.title,
          'Heading',
          () => _text.setKind(ParaKind.h1),
          on: para.kind == ParaKind.h1,
        ),
        tool(
          Icons.text_fields,
          'Subheading',
          () => _text.setKind(ParaKind.h2),
          on: para.kind == ParaKind.h2,
        ),
        tool(
          Icons.format_list_bulleted,
          'Bullet list',
          () => _text.setKind(ParaKind.bullet),
          on: para.kind == ParaKind.bullet,
        ),
        tool(
          Icons.format_list_numbered,
          'Numbered list',
          () => _text.setKind(ParaKind.numbered),
          on: para.kind == ParaKind.numbered,
        ),
        tool(
          Icons.text_decrease,
          'Smaller text',
          () => _text.setBits(maskSize, flags & flagSmall != 0 ? 0 : flagSmall),
          on: flags & flagSmall != 0,
        ),
        tool(
          Icons.text_increase,
          'Larger text',
          () => _text.setBits(maskSize, flags & flagLarge != 0 ? 0 : flagLarge),
          on: flags & flagLarge != 0,
        ),
        PopupMenuButton<int>(
          tooltip: 'Text colour',
          icon: Icon(
            Icons.format_color_text,
            color: _swatch[colorIndex(flags)],
          ),
          onSelected: (i) => _text.setBits(maskColor, i << colorShift),
          itemBuilder: (_) => [
            for (var i = 0; i < _swatch.length; i++)
              PopupMenuItem(
                value: i,
                child: Row(
                  children: [
                    Icon(Icons.circle, color: _swatch[i], size: 16),
                    const SizedBox(width: 8),
                    Text(_swatchNames[i]),
                  ],
                ),
              ),
          ],
        ),
        tool(
          Icons.format_align_left,
          'Align to start',
          () => _text.setAlign(ParaAlign.start),
          on: para.align == ParaAlign.start,
        ),
        tool(
          Icons.format_align_center,
          'Center',
          () => _text.setAlign(ParaAlign.center),
          on: para.align == ParaAlign.center,
        ),
        tool(
          Icons.format_align_right,
          'Align to end',
          () => _text.setAlign(ParaAlign.end),
          on: para.align == ParaAlign.end,
        ),
        tool(
          Icons.format_align_justify,
          'Justify',
          () => _text.setAlign(ParaAlign.justify),
          on: para.align == ParaAlign.justify,
        ),
      ],
    );
  }

  Widget _previewPane() =>
      PaperPreview(key: _preview, doc: _doc, fontSize: _font);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_text.doc);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Write on paper'),
          actions: [
            if (wide || _showPreview)
              PrintButton(busy: _busy, onPressed: () => unawaited(_print())),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_text.doc),
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
