// Renders brands/<BRAND>/logo.svg into the source PNGs the icon and splash
// packages need, so one SVG drives every image:
//   assets/brand/icon_1024.png         full-bleed app icon (iOS, macOS, Windows, legacy Android)
//   assets/brand/icon_foreground.png   Android adaptive-icon foreground (logo without its tile, in the safe zone)
//   assets/brand/splash.png            native splash logo (transparent)
//   assets/brand/splash_android12.png  Android 12+ splash icon (fits the circular mask)
// Run through `make icons BRAND=<id>`, which then runs flutter_launcher_icons
// and flutter_native_splash to write the per-platform files.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// The logo's background tile (a full-size `<rect>`); removed for transparent variants.
final _tile = RegExp(r'<rect[^>]*width="256"[^>]*height="256"[^>]*/>');

/// Draws [svg] centred on a transparent [canvasPx] square, scaled to [logoFraction] of it.
Future<Uint8List> render(String svg, int canvasPx, {double logoFraction = 1}) async {
  final info = await vg.loadPicture(SvgStringLoader(svg), null);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final logoPx = canvasPx * logoFraction;
  canvas.translate((canvasPx - logoPx) / 2, (canvasPx - logoPx) / 2);
  canvas.scale(logoPx / info.size.width, logoPx / info.size.height);
  canvas.drawPicture(info.picture);
  final image = await recorder.endRecording().toImage(canvasPx, canvasPx);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('generate icon and splash source images', (tester) async {
    final brand = Platform.environment['BRAND'] ?? 'demo';
    final svg = File('../brands/$brand/logo.svg').readAsStringSync();
    final bare = svg.replaceFirst(_tile, '');
    await tester.runAsync(() async {
      final out = {
        'icon_1024.png': await render(svg, 1024),
        'icon_foreground.png': await render(bare, 1024, logoFraction: 0.62),
        'splash.png': await render(bare, 768),
        'splash_android12.png': await render(bare, 960, logoFraction: 0.6),
      };
      Directory('assets/brand').createSync(recursive: true);
      for (final e in out.entries) {
        File('assets/brand/${e.key}').writeAsBytesSync(e.value);
      }
    });
  });
}
