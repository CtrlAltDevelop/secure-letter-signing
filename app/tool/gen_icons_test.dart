// Renders brands/<BRAND>/logo.svg into every platform's app icon files.
//   cd app && BRAND=demo flutter test tool/gen_icons_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics/vector_graphics.dart';
import 'package:flutter_svg/flutter_svg.dart';

Future<Uint8List> render(String svg, int px) async {
  final info = await vg.loadPicture(SvgStringLoader(svg), null);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.scale(px / info.size.width, px / info.size.height);
  canvas.drawPicture(info.picture);
  final image = await recorder.endRecording().toImage(px, px);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('generate icons', (tester) async {
    final brand = Platform.environment['BRAND'] ?? 'demo';
    final svg = File('../brands/$brand/logo.svg').readAsStringSync();
    await tester.runAsync(() async {
      Future<void> write(String path, int px) async {
        final f = File(path);
        if (!f.parent.existsSync()) return;
        f.writeAsBytesSync(await render(svg, px));
      }

      for (final px in [16, 32, 64, 128, 256, 512, 1024]) {
        await write('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$px.png', px);
      }
      final ios = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      if (ios.existsSync()) {
        for (final f in ios.listSync().whereType<File>().where((f) => f.path.endsWith('.png'))) {
          final dim = await decodeSize(f);
          if (dim > 0) f.writeAsBytesSync(await render(svg, dim));
        }
      }
      const android = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
      for (final e in android.entries) {
        await write('android/app/src/main/res/mipmap-${e.key}/ic_launcher.png', e.value);
      }
      await write('assets/brand/icon_1024.png', 1024);
    });
  });
}

/// Width of an existing PNG (reads the IHDR chunk), so iOS icons keep their sizes.
Future<int> decodeSize(File f) async {
  final b = f.readAsBytesSync();
  if (b.length < 24) return 0;
  return ByteData.sublistView(b).getUint32(16);
}
