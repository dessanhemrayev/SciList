import 'package:flutter_test/flutter_test.dart';
import 'package:scilist/core/utils/version_compare.dart';

void main() {
  group('VersionCompare.compare', () {
    test('1.10.0 новее 1.9.0', () {
      expect(VersionCompare.compare('1.10.0', '1.9.0'), 1);
      expect(VersionCompare.compare('1.9.0', '1.10.0'), -1);
    });

    test('1.1.1 равна 1.1.1', () {
      expect(VersionCompare.compare('1.1.1', '1.1.1'), 0);
    });

    test('v-префикс игнорируется', () {
      expect(VersionCompare.compare('v1.1.1', '1.1.1'), 0);
      expect(VersionCompare.compare('v1.2.0', 'v1.1.9'), 1);
      expect(VersionCompare.compare('V2.0.0', 'v1.9.9'), 1);
    });

    test('сравнение по сегментам, а не по длине строки', () {
      expect(VersionCompare.compare('1.2', '1.1.9'), 1);
      expect(VersionCompare.compare('1.10.11', '1.10.2'), 1);
      expect(VersionCompare.compare('2.0', '1.99.99'), 1);
      expect(VersionCompare.compare('1.0.1', '1'), 1);
    });

    test('недостающие сегменты считаются нулями', () {
      expect(VersionCompare.compare('1.1', '1.1.0'), 0);
      expect(VersionCompare.compare('1.1.0', '1.1'), 0);
      expect(VersionCompare.compare('1', '1.0.0'), 0);
    });

    test('сборка +BUILD не влияет на сравнение', () {
      expect(VersionCompare.compare('1.1.1+3', '1.1.1+9'), 0);
      expect(VersionCompare.compare('1.1.2+4', '1.1.1+3'), 1);
    });

    test('пре-релиз старее релиза', () {
      expect(VersionCompare.compare('1.2.0-beta', '1.2.0'), -1);
      expect(VersionCompare.compare('1.2.0', '1.2.0-rc1'), 1);
      expect(VersionCompare.compare('1.2.0-beta1', '1.2.0-beta2'), 0);
    });

    test('нечисловые сегменты не ломают разбор', () {
      expect(VersionCompare.compare('1.x.3', '1.0.3'), 0);
      expect(VersionCompare.compare('', '0.0.0'), 0);
      expect(VersionCompare.compare('v', '0.0.0'), 0);
    });

    test('пробелы вокруг версии игнорируются', () {
      expect(VersionCompare.compare(' v1.1.1 ', '1.1.1'), 0);
    });
  });

  group('VersionCompare.isNewer / isSame / normalize', () {
    test('isNewer', () {
      expect(VersionCompare.isNewer('v1.1.2', '1.1.1'), isTrue);
      expect(VersionCompare.isNewer('1.1.1', 'v1.1.1'), isFalse);
      expect(VersionCompare.isNewer('1.0.0', '1.1.0'), isFalse);
    });

    test('isSame', () {
      expect(VersionCompare.isSame('1.1', 'v1.1.0'), isTrue);
      expect(VersionCompare.isSame('1.1.1', '1.1.0'), isFalse);
    });

    test('normalize', () {
      expect(VersionCompare.normalize(' v1.1.1+3 '), '1.1.1');
      expect(VersionCompare.normalize('1.2.0-rc1'), '1.2.0-rc1');
      expect(VersionCompare.normalize('2.0.0'), '2.0.0');
    });
  });
}