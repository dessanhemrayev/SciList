/// Сравнение версий вида `1.2.3`, `v1.2.3`, `1.2`, `1.2.3-beta`.
///
/// Сравнение идёт по числам, а не по строкам, иначе `1.10.0` оказалось бы
/// меньше `1.9.0`. Отсутствующие сегменты считаются нулями: `1.1` == `1.1.0`.
class VersionCompare {
  static final RegExp _vPrefix = RegExp(r'^[vV]');
  static final RegExp _leadingDigits = RegExp(r'^\d+');

  /// Возвращает 1, если [a] новее [b], -1, если старее, и 0 при равенстве.
  static int compare(String a, String b) {
    final left = _parse(a);
    final right = _parse(b);

    final length = left.parts.length > right.parts.length
        ? left.parts.length
        : right.parts.length;

    for (var i = 0; i < length; i++) {
      final leftPart = i < left.parts.length ? left.parts[i] : 0;
      final rightPart = i < right.parts.length ? right.parts[i] : 0;
      if (leftPart != rightPart) return leftPart > rightPart ? 1 : -1;
    }

    // 1.2.0-beta старее 1.2.0
    if (left.isPrerelease != right.isPrerelease) {
      return left.isPrerelease ? -1 : 1;
    }

    return 0;
  }

  static bool isNewer(String candidate, String current) {
    return compare(candidate, current) > 0;
  }

  static bool isSame(String a, String b) => compare(a, b) == 0;

  /// Убирает префикс `v`, хвост сборки `+3` и пробелы.
  static String normalize(String version) {
    var value = version.trim();
    value = value.replaceFirst(_vPrefix, '');
    final plus = value.indexOf('+');
    if (plus != -1) value = value.substring(0, plus);
    return value.trim();
  }

  static ({List<int> parts, bool isPrerelease}) _parse(String version) {
    var value = normalize(version);

    var isPrerelease = false;
    final dash = value.indexOf('-');
    if (dash != -1) {
      isPrerelease = true;
      value = value.substring(0, dash);
    }

    final parts = <int>[];
    for (final segment in value.split('.')) {
      final match = _leadingDigits.firstMatch(segment.trim());
      parts.add(match == null ? 0 : int.parse(match.group(0)!));
    }

    if (parts.isEmpty) parts.add(0);

    return (parts: parts, isPrerelease: isPrerelease);
  }
}