import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

/// Company header/footer printed on letters. Filled by the manager (Admin tab).
@immutable
class Letterhead {
  const Letterhead({
    this.name = '',
    this.tagline = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.footer = '',
    this.logo = '',
  });

  final String name;
  final String tagline;
  final String address;
  final String phone;
  final String email;
  final String website;
  final String footer;

  /// `data:image/png;base64,...` or jpeg, or empty.
  final String logo;

  static const textFields = [
    'name',
    'tagline',
    'address',
    'phone',
    'email',
    'website',
    'footer',
  ];

  factory Letterhead.fromJson(Map<String, dynamic> j) {
    String s(String k) => (j[k] as String?) ?? '';
    return Letterhead(
      name: s('name'),
      tagline: s('tagline'),
      address: s('address'),
      phone: s('phone'),
      email: s('email'),
      website: s('website'),
      footer: s('footer'),
      logo: s('logo'),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'tagline': tagline,
    'address': address,
    'phone': phone,
    'email': email,
    'website': website,
    'footer': footer,
    'logo': logo,
  };

  Letterhead copyWith({String? logo}) =>
      Letterhead.fromJson({...toJson(), 'logo': ?logo});

  bool get isEmpty => toJson().values.every((v) => (v as String).isEmpty);

  /// Contact line under the name: address, phone, email, website.
  String get contactLine =>
      [address, phone, email, website].where((s) => s.isNotEmpty).join('  |  ');

  /// Decoded logo. The same instance is returned for the same data URL, so
  /// `Image.memory` keeps its cached image instead of reloading on every
  /// rebuild (e.g. on each keystroke in the letterhead form).
  Uint8List? get logoBytes {
    if (logo == _lastLogo) return _lastBytes;
    final i = logo.indexOf('base64,');
    Uint8List? bytes;
    if (i >= 0) {
      try {
        bytes = base64Decode(logo.substring(i + 7));
      } on FormatException {
        bytes = null;
      }
    }
    _lastLogo = logo;
    _lastBytes = bytes;
    return bytes;
  }
}

// ponytail: one-entry cache; only one logo is shown at a time.
String _lastLogo = '';
Uint8List? _lastBytes;

/// Paper colours of the original HTML app's letterhead.
const Color paperInk = Color(0xFF081528);
const Color paperBrand = Color(0xFF165EF6);
const Color paperMid = Color(0xFF32568A);
const Color paperGold = Color(0xFFBFA46F);

/// Printed header, same look as the original HTML letters: logo on the start edge,
/// bold brand-blue name, grey-blue tagline, then a blue rule over a thin gold rule.
class LetterheadHeader extends StatelessWidget {
  const LetterheadHeader({super.key, required this.head});
  final Letterhead head;

  @override
  Widget build(BuildContext context) {
    if (head.isEmpty) return const SizedBox.shrink();
    final bytes = head.logoBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (bytes != null) ...[
              Image.memory(
                bytes,
                height: 72,
                width: 72,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (head.name.isNotEmpty)
                    Text(
                      head.name,
                      style: const TextStyle(
                        color: paperBrand,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (head.tagline.isNotEmpty)
                    Text(
                      head.tagline,
                      style: const TextStyle(color: paperMid, fontSize: 14),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1.5, color: paperBrand),
        const SizedBox(height: 4),
        const Divider(height: 1, thickness: 1, color: paperGold),
      ],
    );
  }
}

/// Footer text under the gold rule: the footer field, else the address/phone/... line.
extension LetterheadFooter on Letterhead {
  String get footerText => footer.isNotEmpty ? footer : contactLine;
}
