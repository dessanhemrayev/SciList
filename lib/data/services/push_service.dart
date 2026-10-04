import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/constants/push_constants.dart';

/// Тонкая обёртка над Firebase Cloud Messaging.
///
/// Свой бэкенд и хранилище токенов не нужны: приложение подписывается на общий
/// топик [PushConstants.topic], а отправляет в него сервисный аккаунт из CI
/// (см. `docs/fcm-update-notifications.md`).
///
/// Ошибка инициализации гасится и оставляет [isAvailable] равным false: push дополняет
/// проверку обновлений при запуске и не должен ломать запуск. Именно так себя
/// ведёт приложение на устройствах без Google Play Services.
class PushService {
  /// [messaging] внедряется только в тестах: конструктор не должен
  /// обращаться к платформе, иначе сервис нельзя подменить фейком.
  PushService({FirebaseMessaging? messaging}) : _messagingOverride = messaging;

  final FirebaseMessaging? _messagingOverride;

  bool _initialized = false;
  bool _available = false;

  /// Потоки в firebase_messaging статические, поэтому подменяется только
  /// объект с методами.
  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;

  /// Готов ли FCM к работе: нет `google-services.json`, нет Google Play
  /// Services или платформа не поддерживается.
  bool get isAvailable => _available;

  /// Без файла `google-services.json` падает даже на устройстве с
  /// Google Play Services, поэтому ошибка не пробрасывается.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (_) {
      _available = false;
    }
  }

  /// Сообщение, по которому открыли приложение из уведомления, когда оно
  /// было закрыто. Возвращается один раз.
  Future<RemoteMessage?> takeInitialMessage() async {
    if (!_available) return null;
    try {
      return await _messaging.getInitialMessage();
    } catch (_) {
      return null;
    }
  }

  /// Сообщение пришло, пока приложение открыто: уведомление в трее Android
  /// в этом случае не показывается, диалог строит приложение.
  Stream<RemoteMessage> get onMessage => _available
      ? FirebaseMessaging.onMessage
      : const Stream<RemoteMessage>.empty();

  /// Тап по уведомлению, когда приложение было свёрнуто.
  Stream<RemoteMessage> get onMessageOpened => _available
      ? FirebaseMessaging.onMessageOpenedApp
      : const Stream<RemoteMessage>.empty();

  /// Уже выданное разрешение: чтобы не показывать системный диалог повторно.
  Future<bool> hasPermission() async {
    if (!_available) return false;
    try {
      return _isGranted(await _messaging.getNotificationSettings());
    } catch (_) {
      return false;
    }
  }

  /// Android 13+ требует POST_NOTIFICATIONS. Спрашиваем только в момент
  /// включения переключателя в настройках, при старте приложения — никогда.
  Future<bool> requestPermission() async {
    if (!_available) return false;
    try {
      return _isGranted(await _messaging.requestPermission());
    } catch (_) {
      return false;
    }
  }

  Future<void> subscribe() async {
    if (!_available) return;
    try {
      await _messaging.subscribeToTopic(PushConstants.topic);
    } catch (_) {
      rethrow;
    }
  }

  Future<void> unsubscribe() async {
    if (!_available) return;
    try {
      await _messaging.unsubscribeFromTopic(PushConstants.topic);
    } catch (_) {
      // То же самое: отписка не удалась, уведомления продолжат приходить
    }
  }

  static bool _isGranted(NotificationSettings settings) {
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }
}