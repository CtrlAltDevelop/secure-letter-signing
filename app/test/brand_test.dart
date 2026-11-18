import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/brand.dart';

void main() {
  const valid = '{"id":"demo","name":"Demo","apiUrl":"http://x",'
      '"colors":{"primary":"#165EF6","accent":"#BFA46F","dark":"#081528"}}';

  test('parses a valid brand', () {
    final brand = Brand.fromJson(valid);
    expect(brand.name, 'Demo');
    expect(brand.primary.toARGB32(), 0xFF165EF6);
  });

  test('throws when a required key is missing', () {
    expect(() => Brand.fromJson('{"id":"x"}'), throwsFormatException);
  });

  test('throws on a malformed color', () {
    expect(() => parseHex('#12'), throwsFormatException);
  });
}
