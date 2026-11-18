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
      Letterhead.fromJson({...toJson(), if (logo != null) 'logo': logo});

  bool get isEmpty => toJson().values.every((v) => (v as String).isEmpty);

  /// Contact line under the name: address, phone, email, website.
  String get contactLine =>
      [address, phone, email, website].where((s) => s.isNotEmpty).join('  |  ');

  Uint8List? get logoBytes {
    final i = logo.indexOf('base64,');
    if (i < 0) return null;
    try {
      return base64Decode(logo.substring(i + 7));
    } on FormatException {
      return null;
    }
  }
}

/// The printed header: logo left, name/tagline, a rule and the contact line.
class LetterheadHeader extends StatelessWidget {
  const LetterheadHeader({super.key, required this.head, this.ink});
  final Letterhead head;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    if (head.isEmpty) return const SizedBox.shrink();
    final color = ink ?? const Color(0xFF111827);
    final bytes = head.logoBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (bytes != null) ...[
              Image.memory(bytes, height: 52, width: 52, fit: BoxFit.contain),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (head.name.isNotEmpty)
                    Text(
                      head.name,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (head.tagline.isNotEmpty)
                    Text(
                      head.tagline,
                      style: TextStyle(color: color, fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Divider(height: 1, thickness: 1.2, color: color),
        if (head.contactLine.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              head.contactLine,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 9),
            ),
          ),
      ],
    );
  }
}
