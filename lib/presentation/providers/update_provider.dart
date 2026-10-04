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

  /// Проверка при старте: не чаще раза в [checkInterval].
  /// Возвращает обновление, о котором стоит показать диалог, иначе null.
  Future<UpdateInfo?> checkOnStartup() async {
    if (!isCheckDue) return null;

    final result = await checkForUpdates();
    final update = _availableUpdate;
    if (result != UpdateCheckResult.updateAvailable || update == null) return null;
    if (isSkipped(update.version)) return null;
    return update;
  }

  /// Ручная проверка игнорирует таймер.
  Future<UpdateCheckResult> checkForUpdates({bool force = false}) async {
    if (_isChecking) return UpdateCheckResult.failed;
    if (!force && !isCheckDue) return UpdateCheckResult.upToDate;

    _isChecking = true;
    notifyListeners();

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
      _isChecking = false;
      // При неудаче время не запоминаем: иначе после запуска без сети
      // следующая проверка отложилась бы ещё на 6 часов.
      if (result != UpdateCheckResult.failed) {
        await _prefs.setInt(
          UpdateConstants.lastCheckKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      notifyListeners();
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