import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/push_constants.dart';
import '../../data/services/push_service.dart';

enum PushToggleResult {
  /// Состояние переключателя применено.
  updated,

  /// Пользователь не разрешил уведомления.
  permissionDenied,

  /// На устройстве нет Google Play Services или файла `google-services.json`.
  unavailable,
}

/// Состояние push-уведомлений о новых релизах.
///
/// По умолчанию выключено: разрешение `POST_NOTIFICATIONS` спрашивается не при
/// старте, а в момент, когда пользователь включает переключатель в настройках.
///
/// Пришедшие сообщения складываются в очередь: push может прийти раньше, чем
/// подпишется виджет, который показывает диалог.
class PushProvider extends ChangeNotifier {
  PushProvider(this._prefs, {PushService? service})
      : _service = service ?? PushService() {
    _enabled = _prefs.getBool(PushConstants.enabledKey) ?? false;
    unawaited(_initialize());
  }

  final SharedPreferences _prefs;
  final PushService _service;

  final List<RemoteMessage> _messages = [];
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  bool _enabled = false;
  bool _isBusy = false;
  bool _permissionGranted = false;
  bool _disposed = false;

  /// Сохранённое намерение пользователя.
  bool get isEnabled => _enabled;

  /// Уведомления действительно включены: FCM работает, подписка есть и
  /// разрешение ещё не отозвано в системных настройках.
  bool get isActive =>
      _enabled && _service.isAvailable && _permissionGranted;

  bool get isAvailable => _service.isAvailable;
  bool get isBusy => _isBusy;
  bool get hasMessages => _messages.isNotEmpty;

  /// Перечитать разрешение. Пользователь мог отозвать его в системных
  /// настройках, а переключатель об этом не узнает сам. Вызывается при
  /// открытии настроек, где переключатель и виден.
  Future<void> refreshPermission() async {
    if (!_service.isAvailable) return;
    final granted = await _service.hasPermission();
    if (_permissionGranted == granted) return;
    _permissionGranted = granted;
    notifyListeners();
  }

  /// Забрать очередное сообщение, [hasMessages] сообщает, есть ли что забирать.
  RemoteMessage? takeMessage() {
    if (_messages.isEmpty) return null;
    return _messages.removeAt(0);
  }

  /// Включает или выключает уведомления. При включении сначала спрашивается
  /// разрешение: без него Android 13+ не покажет уведомления, а подписка
  /// на топик без разрешения бессмысленна.
  Future<PushToggleResult> setEnabled(bool value) async {
    if (_isBusy) return PushToggleResult.updated;
    _isBusy = true;
    notifyListeners();

    try {
      if (!value) {
        await _service.unsubscribe();
        return await _store(false);
      }

      if (!_service.isAvailable) return PushToggleResult.unavailable;

      final granted = await _service.hasPermission() ||
          await _service.requestPermission();
      _permissionGranted = granted;
      if (!granted) return PushToggleResult.permissionDenied;

      await _service.subscribe();
      return await _store(true);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<PushToggleResult> _store(bool value) async {
    _enabled = value;
    // Выключили уведомления: накопленные сообщения устарели и не должны
    // всплыть диалогом уже после этого
    if (!value) _messages.clear();
    await _prefs.setBool(PushConstants.enabledKey, value);
    return PushToggleResult.updated;
  }

  /// После каждого `await` проверяется [_disposed]: провайдер могли
  /// уничтожить, пока шла инициализация Firebase, и подписки нельзя
  /// создавать уже после этого.
  Future<void> _initialize() async {
    await _service.initialize();
    if (_disposed) return;
    if (!_service.isAvailable) {
      notifyListeners();
      return;
    }

    // Разрешение могли отозвать, пока приложение не запускалось
    if (_enabled) {
      final granted = await _service.hasPermission();
      if (_disposed) return;
      _permissionGranted = granted;
    }

    // Сообщение в открытое приложение приходит без участия пользователя, и
    // если уведомления выключены (в том числе после неудачной отписки),
    // диалог показывать нельзя. Тап по уведомлению в трее, наоборот, явное
    // действие пользователя: на него диалог нужен при любой настройке.
    _messageSub = _service.onMessage.listen((message) {
      if (isActive) _enqueue(message);
    });
    _messageOpenedSub = _service.onMessageOpened.listen(_enqueue);

    final initial = await _service.takeInitialMessage();
    if (_disposed) return;
    // Сообщение из уведомления попадает в ту же очередь, что и остальные.
    // Одно уведомление подписчиков покрывает и появление isAvailable.
    if (initial != null) _messages.add(initial);
    notifyListeners();
  }

  void _enqueue(RemoteMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  /// Асинхронные методы (`setEnabled`, `refreshPermission`) могут закончиться
  /// после [dispose], а уведомлять уничтоженный провайдер нельзя.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_messageSub?.cancel());
    unawaited(_messageOpenedSub?.cancel());
    super.dispose();
  }
}
