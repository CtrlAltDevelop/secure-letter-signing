import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';

const _thousands = '٬';

/// `1234567` -> `۱٬۲۳۴٬۵۶۷` (Persian digits and separators; a minus sign stays ASCII).
String formatAmount(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(_thousands);
    out.write(digits[i]);
  }
  return toPersianDigits(out);
}

/// `۱٬۲۳۴ ریال`.
String formatRial(AppLocalizations l, int value) =>
    '${formatAmount(value)} ${l.commonRial}';

/// Reads what the user typed: ASCII, Persian or Arabic digits, with or without separators.
/// Null when it is not a whole non-negative number.
int? parseAmount(String text) {
  final buf = StringBuffer();
  for (final r in text.runes) {
    if (r >= 0x30 && r <= 0x39) {
      buf.writeCharCode(r);
    } else if (r >= 0x6F0 && r <= 0x6F9) {
      buf.writeCharCode(r - 0x6F0 + 0x30);
    } else if (r >= 0x660 && r <= 0x669) {
      buf.writeCharCode(r - 0x660 + 0x30);
    } else if (r == 0x2C || r == 0x66C || r == 0x60C || r == 0x20) {
      continue;
    } else {
      return null;
    }
  }
  return int.tryParse(buf.toString());
}

/// A `YYYY-MM-DD` server date as a local midnight [DateTime].
DateTime? parseDay(Object? value) {
  if (value is! String || value.length < 10) return null;
  final d = DateTime.tryParse(value.substring(0, 10));
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// `YYYY-MM-DD` of the local calendar day of [d].
String dayIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// An amount shown left-to-right so signs and digit groups never reorder in RTL text.
class AmountText extends StatelessWidget {
  const AmountText(this.value, {super.key, this.style, this.withUnit = false});
  final int value;
  final TextStyle? style;
  final bool withUnit;

  @override
  Widget build(BuildContext context) {
    final text = withUnit
        ? formatRial(AppLocalizations.of(context), value)
        : formatAmount(value);
    return Text(text, style: style, textDirection: TextDirection.ltr);
  }
}
