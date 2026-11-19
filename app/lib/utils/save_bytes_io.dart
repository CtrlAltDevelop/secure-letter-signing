import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet with [bytes] as a file called [name].
Future<void> saveBytes(
  Uint8List bytes, {
  required String name,
  String? mimeType,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: mimeType)],
      fileNameOverrides: [name],
    ),
  );
}
