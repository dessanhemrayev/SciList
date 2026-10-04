import 'package:flutter/services.dart';
import 'issn_validator.dart';

class IssnInputFormatter extends TextInputFormatter {
  const IssnInputFormatter();

  static const int _maxDigits = 8;
  static final RegExp _allowedChar = RegExp(r'[0-9Xx]');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final rawText = newValue.text;
    final caret = newValue.selection.isValid
        ? newValue.selection.baseOffset.clamp(0, rawText.length)
        : rawText.length;

    final digits = StringBuffer();
    var digitsBeforeCaret = 0;

    for (var i = 0; i < rawText.length; i++) {
      final char = rawText[i];
      if (!_allowedChar.hasMatch(char)) continue;
      if (digits.length >= _maxDigits) continue;
      if (i < caret) digitsBeforeCaret++;
      digits.write(char.toUpperCase());
    }

    final clean = digits.toString();
    final formatted = IssnValidator.format(clean);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: _caretOffset(digitsBeforeCaret, clean, formatted)),
    );
  }

  int _caretOffset(int digitsBeforeCaret, String clean, String formatted) {
    final count = digitsBeforeCaret.clamp(0, clean.length);
    if (count >= clean.length) return formatted.length;
    if (count >= 4 && formatted.length > clean.length) return count + 1;
    return count;
  }
}