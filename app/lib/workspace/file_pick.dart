import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// A file the user chose, already read into memory.
@immutable
class PickedFile {
  const PickedFile({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
}

typedef FilePickFn = Future<PickedFile?> Function();

const _mimeByExtension = {
  'pdf': 'application/pdf',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'zip': 'application/zip',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

/// MIME type from the file name's extension; unknown ones are opaque bytes.
String mimeForName(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return _mimeByExtension[ext] ?? 'application/octet-stream';
}

/// Opens the system file picker for one file (null when cancelled).
Future<PickedFile?> pickOneFile() async {
  final res = await FilePicker.pickFiles();
  final file = res.firstOrNull;
  if (file == null) return null;
  return PickedFile(
    name: file.name,
    bytes: await file.readAsBytes(),
    contentType: mimeForName(file.name),
  );
}
