import 'dart:convert';
import 'dart:math';

import 'package:letter_signing/keys/key_models.dart';

/// Transfer envelope (file and QR carry the same bytes):
///
/// ```json
/// {"v": 1, "keyId": "<server UserKey id>", "keyFile": <Identity.wrap output>}
/// ```
/// `keyFile` is already encrypted with the key password (PBKDF2 + AES-256-GCM), so the
/// envelope is useless without it. `keyId` lets the importing device keep the same server key.
class KeyEnvelope {
  const KeyEnvelope({required this.keyId, required this.keyFile});
  final String keyId;
  final Map<String, dynamic> keyFile;

  static const version = 1;
  static const fileExtension = 'slkey';

  String encode() =>
      jsonEncode({'v': version, 'keyId': keyId, 'keyFile': keyFile});

  /// Throws [KeyException] when [text] is not an envelope.
  static KeyEnvelope decode(String text) {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['v'] != version) throw const FormatException();
      final id = j['keyId'];
      final file = j['keyFile'];
      if (id is! String || id.isEmpty || file is! Map) {
        throw const FormatException();
      }
      return KeyEnvelope(keyId: id, keyFile: Map<String, dynamic>.from(file));
    } on Object {
      throw const KeyException('This is not a valid key file');
    }
  }
}

/// QR framing. A frame is `SLK1|<transferId>|<index>|<total>|<chunk>` (index is 1-based);
/// chunks are slices of the base64url of the envelope. Frames may arrive in any order,
/// duplicates are fine.
const qrChunkSize = 600;
const _framePrefix = 'SLK1';

List<String> splitQrFrames(String envelope, {int chunkSize = qrChunkSize}) {
  final data = base64Url.encode(utf8.encode(envelope));
  final id = Random.secure().nextInt(0x10000).toRadixString(16).padLeft(4, '0');
  final total = (data.length / chunkSize).ceil();
  return [
    for (var i = 0; i < total; i++)
      '$_framePrefix|$id|${i + 1}|$total|'
          '${data.substring(i * chunkSize, min(data.length, (i + 1) * chunkSize))}',
  ];
}

/// Collects scanned frames. Immutable-style: [add] returns a new assembler.
class QrAssembler {
  const QrAssembler._(this.transferId, this.total, this._chunks);
  const QrAssembler.empty() : this._(null, 0, const {});

  final String? transferId;
  final int total;
  final Map<int, String> _chunks;

  int get received => _chunks.length;
  bool get complete => total > 0 && received == total;

  /// Returns this assembler unchanged for frames that are not ours, a fresh one when a
  /// different transfer starts, otherwise a copy with the chunk added.
  QrAssembler add(String frame) {
    final p = frame.split('|');
    if (p.length != 5 || p[0] != _framePrefix) return this;
    final index = int.tryParse(p[2]);
    final count = int.tryParse(p[3]);
    if (index == null || count == null || index < 1 || index > count) {
      return this;
    }
    final base = p[1] == transferId && count == total
        ? this
        : const QrAssembler.empty();
    return QrAssembler._(p[1], count, {...base._chunks, index: p[4]});
  }

  /// The envelope text. Throws [KeyException] unless [complete].
  String join() {
    if (!complete) throw const KeyException('QR frames are incomplete');
    try {
      final data = [for (var i = 1; i <= total; i++) _chunks[i]!].join();
      return utf8.decode(base64Url.decode(data));
    } on Object {
      throw const KeyException('QR data is corrupted');
    }
  }
}
