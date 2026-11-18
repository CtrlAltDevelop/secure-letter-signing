import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:letter_signing/keys/key_store.dart';
import 'package:letter_signing/keys/key_transfer.dart';
import 'package:letter_signing/keys/key_ui.dart';
import 'package:letter_signing/keys/password_prompt.dart';
import 'package:letter_signing/keys/transfer_codec.dart';

const _frameInterval = Duration(milliseconds: 1500);

/// QR scanning needs a camera plugin: Android, iOS and macOS only (Windows uses file import).
bool get qrScanSupported => const {
  TargetPlatform.android,
  TargetPlatform.iOS,
  TargetPlatform.macOS,
}.contains(defaultTargetPlatform);

/// Export: asks for the key password, then offers file and QR.
Future<void> startKeyExport(BuildContext context, KeyTransfer transfer) async {
  final stored = await transfer.store.load();
  if (!context.mounted) return;
  if (stored == null || stored.sealed) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A biometric-sealed key cannot be exported.'),
      ),
    );
    return;
  }
  final envelope = await showPasswordPrompt<String>(
    context,
    title: 'Export key',
    reason: 'Enter the key password to export this key.',
    verify: transfer.export,
  );
  if (envelope == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => KeyExportScreen(envelope: envelope),
    ),
  );
}

/// Import: file or QR, then the same key password to verify before saving.
/// Returns true when a key was imported.
Future<bool> startKeyImport(BuildContext context, KeyTransfer transfer) async {
  final text = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const KeyImportSourceScreen()),
  );
  if (text == null || !context.mounted) return false;
  final stored = await showPasswordPrompt<StoredKey>(
    context,
    title: 'Import key',
    reason: 'Enter the key password you set on the old device.',
    verify: (pw) => transfer.import(text, pw),
  );
  return stored != null;
}

class KeyExportScreen extends StatelessWidget {
  const KeyExportScreen({super.key, required this.envelope});
  final String envelope;

  Future<void> _shareFile() async {
    final file = File(
      '${Directory.systemTemp.path}/key.${KeyEnvelope.fileExtension}',
    );
    await file.writeAsString(envelope, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Export key')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'This is your encrypted key. It is useless without the key password. '
          'On the new device choose Import key and enter the same password.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => runKeyAction(context, _shareFile),
          icon: const Icon(Icons.ios_share),
          label: const Text('Save or share as file'),
        ),
        const SizedBox(height: 24),
        QrFrameSlideshow(frames: splitQrFrames(envelope)),
      ],
    ),
  );
}

/// Shows [frames] as an auto-advancing QR slideshow (one frame is shown without numbering).
class QrFrameSlideshow extends StatefulWidget {
  const QrFrameSlideshow({super.key, required this.frames});
  final List<String> frames;

  @override
  State<QrFrameSlideshow> createState() => _QrFrameSlideshowState();
}

class _QrFrameSlideshowState extends State<QrFrameSlideshow> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.frames.length > 1) {
      _timer = Timer.periodic(
        _frameInterval,
        (_) => setState(() => _index = (_index + 1) % widget.frames.length),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.frames.length;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: QrImageView(
            data: widget.frames[_index],
            size: 280,
            errorCorrectionLevel: QrErrorCorrectLevel.L,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          count > 1
              ? 'Frame ${_index + 1} of $count. Keep scanning until all are read.'
              : 'Scan with the new device',
        ),
      ],
    );
  }
}

/// Lets the user pick the envelope source; pops with the envelope text.
class KeyImportSourceScreen extends StatelessWidget {
  const KeyImportSourceScreen({super.key});

  Future<void> _pickFile(BuildContext context) async {
    final navigator = Navigator.of(context);
    final file = await FilePicker.pickFile();
    if (file == null) return;
    final text = utf8.decode(await file.readAsBytes());
    KeyEnvelope.decode(text); // fail early on a wrong file
    navigator.pop(text);
  }

  Future<void> _scan(BuildContext context) async {
    final navigator = Navigator.of(context);
    final text = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (text != null) navigator.pop(text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Import key')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        FilledButton.icon(
          onPressed: () => runKeyAction(context, () => _pickFile(context)),
          icon: const Icon(Icons.file_open),
          label: const Text('Choose key file'),
        ),
        const SizedBox(height: 12),
        if (qrScanSupported)
          OutlinedButton.icon(
            onPressed: () => _scan(context),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR code'),
          )
        else
          const Text(
            'QR scanning is not available on this platform; use a file.',
          ),
      ],
    ),
  );
}

/// Scans numbered QR frames until the envelope is complete, then pops with its text.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  QrAssembler _assembler = const QrAssembler.empty();
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    var next = _assembler;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw != null) next = next.add(raw);
    }
    if (next.complete) {
      _done = true;
      Navigator.of(context).pop(next.join());
      return;
    }
    if (next.received != _assembler.received) setState(() => _assembler = next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan key QR')),
    body: Stack(
      children: [
        MobileScanner(onDetect: _onDetect),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            color: Colors.black54,
            padding: const EdgeInsets.all(16),
            child: Text(
              _assembler.total == 0
                  ? 'Point the camera at the QR code'
                  : 'Read ${_assembler.received} of ${_assembler.total} frames',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}
