import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/update_constants.dart';
import '../../data/models/update_info.dart';
import '../../data/services/update_service.dart';

enum UpdateCheckResult { upToDate, updateAvailable, failed }

class UpdateProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final UpdateService _service;

  UpdateInfo? _availableUpdate;
  String? _currentVersion;
  bool _isChecking = false;
  bool _isDownloading = false;
  double? _downloadProgress;
  String? _downloadedApkPath;
  Future<UpdateCheckResult>? _checkFuture;

  UpdateProvider(this._prefs, {UpdateService? service})
      : _service = service ?? UpdateService() {
    _loadCurrentVersion();
  }

  /// Версия из PackageInfo, чтобы в настройках версия была видна сразу.
  Future<void> _loadCurrentVersion() async {
    try {
      _currentVersion = await _service.getCurrentVersion();
      notifyListeners();
    } catch (_) {
      // версия останется null, покажется после успешной проверки
    }
  }

  UpdateInfo? get availableUpdate => _availableUpdate;
  String? get currentVersion => _currentVersion;
  bool get isChecking => _isChecking;
  bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get isDownloading => _isDownloading;
  double? get downloadProgress => _downloadProgress;

  static Duration get checkInterval => Duration(hours: UpdateConstants.checkIntervalHours);

  DateTime? get lastCheckAt {
    final stamp = _prefs.getInt(UpdateConstants.lastCheckKey);
    if (stamp == null || stamp <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(stamp);
  }

  bool get isCheckDue {
    final last = lastCheckAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= checkInterval;
  }

  bool isSkipped(String version) {
    return _prefs.getString(UpdateConstants.skippedVersionKey) == version;
  }

  /// Версии, для которых диалог уже предлагался в этой сессии.
  ///
  /// При запуске из уведомления срабатывают две проверки одновременно — при
  /// старте и по push, — и без этого диалоги открылись бы друг на друге.
  final Set<String> _promptedVersions = <String>{};

  /// Проверка при старте: не чаще раза в [checkInterval].
  /// Возвращает обновление, о котором стоит показать диалог, иначе null.
  Future<UpdateInfo?> checkOnStartup() async {
    if (!isCheckDue) return null;

    final result = await checkForUpdates();
    return _claimForPrompt(result, _availableUpdate);
  }

  /// Проверка по push-уведомлению: таймер игнорируется, но пропущенная
  /// пользователем версия по-прежнему не предлагается.
  Future<UpdateInfo?> checkFromPush() async {
    return (await checkFromPushDetailed()).update;
  }

  /// То же, что [checkFromPush], но с итогом проверки: по null нельзя отличить
  /// «обновлений нет» от сбоя сети, а пользователю, тапнувшему по уведомлению,
  /// при сбое нужно предложить повторить.
  Future<({UpdateCheckResult result, UpdateInfo? update})>
      checkFromPushDetailed() async {
    final result = await checkForUpdates(force: true);
    return (result: result, update: _claimForPrompt(result, _availableUpdate));
  }

  /// Отдаёт версию под диалог ровно один раз: пропущенную пользователем,
  /// уже показанную или при неудачной проверке — нет.
  UpdateInfo? _claimForPrompt(UpdateCheckResult result, UpdateInfo? update) {
    if (result != UpdateCheckResult.updateAvailable) return null;
    if (update == null || isSkipped(update.version)) return null;
    if (!_promptedVersions.add(update.version)) return null;
    return update;
  }

  /// Ручная проверка игнорирует таймер.
  Future<UpdateCheckResult> checkForUpdates({bool force = false}) {
    final pendingCheck = _checkFuture;
    if (pendingCheck != null) return pendingCheck;
    if (!force && !isCheckDue) {
      return Future.value(UpdateCheckResult.upToDate);
    }

    _isChecking = true;
    final check = _checkFuture = Future<UpdateCheckResult>.microtask(_performCheck);
    notifyListeners();
    return check;
  }

  Future<UpdateCheckResult> _performCheck() async {
    var result = UpdateCheckResult.failed;
    try {
      _currentVersion ??= await _service.getCurrentVersion();
      final update = await _service.check();

      if (update == null) {
        _availableUpdate = null;
        result = _service.lastCheckFailed
            ? UpdateCheckResult.failed
            : UpdateCheckResult.upToDate;
        return result;
      }

      _availableUpdate = update;
      result = UpdateCheckResult.updateAvailable;
      return result;
    } catch (_) {
      return UpdateCheckResult.failed;
    } finally {
      // При неудаче время не запоминаем: иначе после запуска без сети
      // следующая проверка отложилась бы ещё на 6 часов.
      try {
        if (result != UpdateCheckResult.failed) {
          await _prefs.setInt(
            UpdateConstants.lastCheckKey,
            DateTime.now().millisecondsSinceEpoch,
          );
        }
      } finally {
        _checkFuture = null;
        _isChecking = false;
        notifyListeners();
      }
    }
  }

  Future<void> skipVersion(String version) async {
    await _prefs.setString(UpdateConstants.skippedVersionKey, version);
    notifyListeners();
  }

  /// Вариант А: браузер скачает APK, пользователь откроет его из уведомления.
  Future<bool> openDownload(UpdateInfo update) async {
    final uri = Uri.tryParse(update.apkUrl);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<bool> downloadUpdate(UpdateInfo update) async {
    if (_isDownloading) return false;
    _isDownloading = true;
    _downloadProgress = null;
    _downloadedApkPath = null;
    notifyListeners();

    try {
      _downloadedApkPath = await _service.downloadApk(
        update,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final progress = (received / total).clamp(0.0, 1.0).toDouble();
          if (_downloadProgress == null ||
              (progress - _downloadProgress!).abs() >= 0.01 ||
              progress == 1) {
            _downloadProgress = progress;
            notifyListeners();
          }
        },
      );
      return true;
    } catch (_) {
      _downloadedApkPath = null;
      return false;
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future<bool> installDownloadedUpdate() async {
    final path = _downloadedApkPath;
    if (path == null) return false;
    return _service.openApk(path);
  }

  Future<bool> openReleasePage(UpdateInfo update) async {
    final uri = Uri.tryParse(update.pageUrl);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
