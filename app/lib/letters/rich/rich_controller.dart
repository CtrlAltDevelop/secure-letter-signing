import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/rich/rich_doc.dart';
import 'package:letter_signing/letters/rich/rich_layout.dart';

/// A text controller that keeps a [RichDoc] in step with the text and paints styles while editing.
/// Alignment and bullets are shown in the A4 preview; bold/italic/underline/headings are visible here.
class RichController extends TextEditingController {
  RichController(RichDoc initial, {this.fontSize = 14})
    : _doc = initial,
      super(text: initial.text);

  RichDoc _doc;
  double fontSize;
  int _typing = 0;
  bool _typingPinned = false;
  final List<RichDoc> _undo = [];
  final List<RichDoc> _redo = [];
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);

  RichDoc get doc => _doc;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Flags used for the next typed character: pinned by a toolbar toggle, else the previous character's.
  int get activeFlags => _typingPinned
      ? _typing
      : _doc.flagsBefore(selection.isValid ? selection.start : 0);

  @override
  set value(TextEditingValue newValue) {
    if (newValue.text != text) {
      _pushUndo();
      _doc = _doc.afterEdit(
        newValue.text,
        _typingPinned ? _typing : _doc.flagsBefore(_selectionStart),
      );
      _typingPinned = false;
    }
    super.value = newValue;
  }

  int get _selectionStart => selection.isValid ? selection.start : 0;

  void _pushUndo() {
    final now = DateTime.now();
    // Typing within 700 ms is one undo step.
    if (_undo.isEmpty || now.difference(_lastPush).inMilliseconds > 700) {
      _undo.add(_doc);
      if (_undo.length > 100) _undo.removeAt(0);
    }
    _lastPush = now;
    _redo.clear();
  }

  void _apply(RichDoc next) {
    _undo.add(_doc);
    _redo.clear();
    _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
    _doc = next;
    notifyListeners();
  }

  void toggle(int flag) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) {
      _typing = activeFlags ^ flag;
      _typingPinned = true;
      notifyListeners();
      return;
    }
    _apply(_doc.toggleFlag(sel.start, sel.end, flag));
  }

  void setKind(ParaKind kind) {
    final sel = selection.isValid
        ? selection
        : const TextSelection.collapsed(offset: 0);
    final all = _doc.paras
        .sublist(_doc.paraAt(sel.start), _doc.paraAt(sel.end) + 1)
        .every((p) => p.kind == kind);
    _apply(
      _doc.mapParas(
        sel.start,
        sel.end,
        (p) => p.copyWith(kind: all ? ParaKind.normal : kind),
      ),
    );
  }

  void setAlign(ParaAlign align) {
    final sel = selection.isValid
        ? selection
        : const TextSelection.collapsed(offset: 0);
    _apply(_doc.mapParas(sel.start, sel.end, (p) => p.copyWith(align: align)));
  }

  ParaStyle get currentPara =>
      _doc.paras[_doc.paraAt(_selectionStart).clamp(0, _doc.paras.length - 1)];

  void undo() => _restore(_undo, _redo);
  void redo() => _restore(_redo, _undo);

  void _restore(List<RichDoc> from, List<RichDoc> to) {
    if (from.isEmpty) return;
    to.add(_doc);
    _doc = from.removeLast();
    final end = _selectionStart.clamp(0, _doc.text.length);
    super.value = TextEditingValue(
      text: _doc.text,
      selection: TextSelection.collapsed(offset: end),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) => editorSpan(_doc, fontSize, style);
}
