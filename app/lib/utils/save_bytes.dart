/// Hands a file's bytes to the user: the share sheet on native platforms, a browser download
/// on web. `saveBytes(bytes, name: 'a.pdf', mimeType: 'application/pdf')`.
library;

export 'save_bytes_io.dart' if (dart.library.js_interop) 'save_bytes_web.dart';
