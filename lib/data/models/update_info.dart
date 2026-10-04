import '../../core/constants/update_constants.dart';
import '../../core/utils/version_compare.dart';

class UpdateInfo {
  final String version;
  final String notes;
  final String apkUrl;
  final String pageUrl;

  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.pageUrl,
  });

  /// Разбирает ответ `GET /repos/{owner}/{repo}/releases/latest`.
  /// Возвращает null, если в релизе нет APK-ассета или он без ссылки.
  static UpdateInfo? fromGitHubJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String?;
    if (tagName == null || tagName.trim().isEmpty) return null;

    final version = VersionCompare.normalize(tagName);
    if (version.isEmpty) return null;

    final apkUrl = _findApkUrl(json['assets']);
    if (apkUrl == null) return null;

    return UpdateInfo(
      version: version,
      notes: (json['body'] as String? ?? '').trim(),
      apkUrl: apkUrl,
      pageUrl: json['html_url'] as String? ?? UpdateConstants.releasesPageUrl,
    );
  }

  static String? _findApkUrl(dynamic assets) {
    if (assets is! List) return null;

    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name'] as String?;
      final url = asset['browser_download_url'] as String?;
      if (name == null || url == null) continue;
      if (name.toLowerCase().endsWith('.apk')) return url;
    }

    return null;
  }

  bool get hasNotes => notes.isNotEmpty;
}