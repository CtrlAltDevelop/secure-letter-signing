import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

/// A square thumbnail of an image that is downloaded through [load] (files need the bearer
/// token, so `Image.network` cannot be used). Shows an icon while loading or when the bytes
/// are not a decodable image.
class FileThumb extends StatefulWidget {
  const FileThumb({super.key, required this.load, this.size = 72});

  final Future<Uint8List> Function() load;
  final double size;

  @override
  State<FileThumb> createState() => _FileThumbState();
}

class _FileThumbState extends State<FileThumb> {
  late final Future<Uint8List> _bytes = widget.load();

  Widget _placeholder(BuildContext context) => Icon(
    Icons.image_outlined,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox.square(
      dimension: widget.size,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (context, snap) {
            final data = snap.data;
            if (data == null) return _placeholder(context);
            return Image.memory(
              data,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => _placeholder(context),
            );
          },
        ),
      ),
    ),
  );
}
