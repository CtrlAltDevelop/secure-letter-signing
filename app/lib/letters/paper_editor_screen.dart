import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/paper_pages.dart';
import 'package:letter_signing/letters/paper_screen.dart';

/// Write the letter body on an A4-style sheet with the company letterhead.
/// Pops the edited text. The exact page breaks are shown by the paper preview.
class PaperEditorScreen extends StatefulWidget {
  const PaperEditorScreen({
    super.key,
    required this.head,
    required this.title,
    required this.initialText,
  });
  final Letterhead head;
  final String title;
  final String initialText;

  @override
  State<PaperEditorScreen> createState() => _PaperEditorScreenState();
}

class _PaperEditorScreenState extends State<PaperEditorScreen> {
  late final _text = TextEditingController(text: widget.initialText);
  double _font = defaultPaperFont;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _preview() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => PaperScreen(
        head: widget.head,
        title: widget.title,
        subtitle: '',
        text: _text.text,
        initialFont: _font,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final dir = isRtlText(_text.text) ? TextDirection.rtl : TextDirection.ltr;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_text.text);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Write on paper'),
          actions: [
            IconButton(
              tooltip: 'Preview / print',
              icon: const Icon(Icons.print_outlined),
              onPressed: _preview,
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_text.text),
              child: const Text('Done'),
            ),
          ],
        ),
        body: Column(
          children: [
            PaperFontSlider(
              value: _font,
              label: 'A4',
              onChanged: (v) => setState(() => _font = v),
            ),
            Expanded(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: a4Width),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: a4Height),
                        padding: const EdgeInsets.all(pageMargin / 2),
                        color: Colors.white,
                        child: Directionality(
                          textDirection: dir,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LetterheadHeader(head: widget.head),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _text,
                                autofocus: true,
                                maxLines: null,
                                minLines: 20,
                                onChanged: (_) => setState(() {}),
                                style: bodyStyle(_font),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  hintText: 'Write the letter here...',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
