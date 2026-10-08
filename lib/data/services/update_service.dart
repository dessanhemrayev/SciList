import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/update_constants.dart';
import '../../core/utils/version_compare.dart';
import '../models/update_info.dart';

/// Проверка новых релизов SciList на GitHub.
///
/// Любая ошибка (нет сети, 403 по лимиту, пустой релиз, нет APK-ассета)
/// гасится и превращается в null: проверка обновлений не должна ломать запуск.
class UpdateService {
  final Dio _dio;

  bool _lastCheckFailed = false;

  /// Различать «обновлений нет» и «проверка не удалась»: ручной кнопке в
  /// настройках нужны разные сообщения.
  bool get lastCheckFailed => _lastCheckFailed;

  UpdateService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(milliseconds: UpdateConstants.connectTimeoutMs),
                receiveTimeout: const Duration(milliseconds: UpdateConstants.receiveTimeoutMs),
                headers: {
                  'Accept': 'application/vnd.github+json',
                  'X-GitHub-Api-Version': '2022-11-28',
                },
              ),
            );

  /// Версия приложения без +build, например `1.1.1`.
  Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Последний релиз или null, если запрос не удался либо APK-ассета нет.
  Future<UpdateInfo?> fetchLatestRelease() async {
    try {
      final response = await _dio.get<dynamic>(UpdateConstants.latestReleaseUrl);
      final data = response.data;
      if (response.statusCode != 200 || data is! Map) {
        _lastCheckFailed = true;
        return null;
      }
      final updateInfo = UpdateInfo.fromGitHubJson(Map<String, dynamic>.from(data));
      if (updateInfo == null) {
        _lastCheckFailed = true;
      }
      return updateInfo;
    } catch (_) {
      _lastCheckFailed = true;
      return null;
    }
  }

  /// null, если обновления нет или проверка не удалась.
  Future<UpdateInfo?> check() async {
    _lastCheckFailed = false;
    try {
      final currentVersion = await getCurrentVersion();
      final latest = await fetchLatestRelease();
      if (latest == null) return null;
      if (!VersionCompare.isNewer(latest.version, currentVersion)) return null;
      return latest;
    } catch (_) {
      _lastCheckFailed = true;
      return null;
    }
  }

  Future<String> downloadApk(
    UpdateInfo update, {
    required void Function(int received, int total) onReceiveProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/scilist-update-${update.version}.apk';
    final file = File(path);
    if (await file.exists()) await file.delete();

    try {
      await _dio.download(
        update.apkUrl,
        path,
        onReceiveProgress: onReceiveProgress,
      );
      return path;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<bool> openApk(String path) async {
    try {
      final result = await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );
      return result.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _dio.close();
  }
}