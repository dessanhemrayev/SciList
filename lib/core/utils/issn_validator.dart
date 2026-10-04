class IssnValidator {
  static final _issnRegex = RegExp(r'^\d{4}-\d{3}[\dX]$');

  static bool isValidFormat(String issn) {
    return _issnRegex.hasMatch(issn.trim().toUpperCase());
  }

  static bool isValidCheckDigit(String issn) {
    final clean = issn.replaceAll('-', '').toUpperCase();
    if (clean.length != 8) return false;

    int sum = 0;
    for (int i = 0; i < 7; i++) {
      sum += int.parse(clean[i]) * (8 - i);
    }

    final checkChar = clean[7];
    int checkDigit;
    if (checkChar == 'X') {
      checkDigit = 10;
    } else {
      checkDigit = int.parse(checkChar);
    }

    final remainder = sum % 11;
    final expectedCheckDigit = remainder == 0 ? 0 : 11 - remainder;

    return checkDigit == expectedCheckDigit;
  }

  static bool isValid(String issn) {
    return isValidFormat(issn) && isValidCheckDigit(issn);
  }

  static String format(String input) {
    final digits = input.replaceAll(RegExp(r'[^\dX]'), '').toUpperCase();
    if (digits.length <= 4) {
      return digits;
    }
    return '${digits.substring(0, 4)}-${digits.substring(4)}';
  }

  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите ISSN';
    }
    final formatted = format(value);
    if (!isValidFormat(formatted)) {
      return 'Формат: XXXX-XXXX (8 цифр)';
    }
    if (!isValidCheckDigit(formatted)) {
      return 'Неверный контрольный номер ISSN';
    }
    return null;
  }
}