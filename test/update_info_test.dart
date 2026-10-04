import 'package:flutter_test/flutter_test.dart';
import 'package:scilist/data/models/update_info.dart';

void main() {
  const apkUrl = 'https://github.com/dessanhemrayev/SciList/releases/download/v1.1.1/SciList-v1.1.1.apk';

  Map<String, dynamic> releaseJson({
    String tagName = 'v1.1.1',
    String? body = 'Что-то новое',
    List<Map<String, String>>? assets,
  }) {
    return {
      'tag_name': tagName,
      'body': body,
      'html_url': 'https://github.com/dessanhemrayev/SciList/releases/tag/v1.1.1',
      'assets': assets ??
          [
            {'name': 'SciList-v1.1.1.apk', 'browser_download_url': apkUrl},
          ],
    };
  }

  group('UpdateInfo.fromGitHubJson', () {
    test('разбирает тег без v-префикса', () {
      final info = UpdateInfo.fromGitHubJson(releaseJson());
      expect(info, isNotNull);
      expect(info!.version, '1.1.1');
      expect(info.notes, 'Что-то новое');
      expect(info.apkUrl, apkUrl);
      expect(info.pageUrl, contains('/releases/tag/v1.1.1'));
    });

    test('пустые заметки', () {
      final info = UpdateInfo.fromGitHubJson(releaseJson(body: '   '));
      expect(info!.notes, '');
      expect(info.hasNotes, isFalse);
    });

    test('отсутствие заметок', () {
      final info = UpdateInfo.fromGitHubJson(releaseJson(body: null));
      expect(info!.hasNotes, isFalse);
    });

    test('выбирает apk среди прочих ассетов', () {
      final info = UpdateInfo.fromGitHubJson(
        releaseJson(
          assets: [
            {'name': 'scilist-1.1.1-source.zip', 'browser_download_url': 'https://example.com/a.zip'},
            {'name': 'SciList.APK', 'browser_download_url': apkUrl},
            {'name': 'app-release.aab', 'browser_download_url': 'https://example.com/b.aab'},
          ],
        ),
      );
      expect(info!.apkUrl, apkUrl);
    });

    test('нет apk-ассета', () {
      final info = UpdateInfo.fromGitHubJson(
        releaseJson(
          assets: [
            {'name': 'notes.txt', 'browser_download_url': 'https://example.com/notes.txt'},
          ],
        ),
      );
      expect(info, isNull);
    });

    test('пустой список ассетов', () {
      expect(UpdateInfo.fromGitHubJson(releaseJson(assets: [])), isNull);
    });

    test('нет ключа assets', () {
      final json = releaseJson()..remove('assets');
      expect(UpdateInfo.fromGitHubJson(json), isNull);
    });

    test('пустой или отсутствующий tag_name', () {
      expect(UpdateInfo.fromGitHubJson(releaseJson(tagName: '')), isNull);
      final json = releaseJson()..remove('tag_name');
      expect(UpdateInfo.fromGitHubJson(json), isNull);
    });
  });
}