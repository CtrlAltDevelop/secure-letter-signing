import 'dart:ui' show PointerDeviceKind;

import 'package:material_ui/material_ui.dart';

/// Hides the desktop scrollbar everywhere. Scrolling itself still works with
/// the mouse wheel, trackpad, touch and by dragging with the mouse.
class NoScrollbarBehavior extends MaterialScrollBehavior {
  const NoScrollbarBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
