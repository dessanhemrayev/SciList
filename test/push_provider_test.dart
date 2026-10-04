import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scilist/core/constants/push_constants.dart';
import 'package:scilist/data/services/push_service.dart';
import 'package:scilist/presentation/providers/push_provider.dart';

class _FakePushService extends PushService {
  _FakePushService({
    this.available = true,
    this.permissionGranted = true,
    this.initialMessage,
  });

  final bool available;

  /// Разрешение можно менять между проверками — так имитируется отзыв
  /// разрешения в системных настройках.
  bool permissionGranted;
  final RemoteMessage? initialMessage;

  final StreamController<RemoteMessage> _messages =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> _opened =
      StreamController<RemoteMessage>.broadcast();

  int subscribeCalls = 0;
  int unsubscribeCalls = 0;
  int permissionRequests = 0;

  void emit(RemoteMessage message) => _messages.add(message);
  void emitOpened(RemoteMessage message) => _opened.add(message);

  @override
  Future<void> initialize() async {}

  @override
  bool get isAvailable => available;

  @override
  Stream<RemoteMessage> get onMessage => _messages.stream;

  @override
  Stream<RemoteMessage> get onMessageOpened => _opened.stream;

  @override
  Future<RemoteMessage?> takeInitialMessage() async => initialMessage;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> subscribe() async => subscribeCalls++;

  @override
  Future<void> unsubscribe() async => unsubscribeCalls++;

  Future<void> close() async {
    await _messages.close();
    await _opened.close();
  }
}

/// Провайдер инициализирует FCM асинхронно, поэтому в тестах ждём его.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

Future<SharedPreferences> _prefs({Map<String, Object> values = const {}}) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  test('по умолчанию уведомления выключены', () async {
    final service = _FakePushService();
    final provider = PushProvider(await _prefs(), service: service);
    addTearDown(provider.dispose);
    await _settle();

    expect(provider.isEnabled, isFalse);
    expect(provider.isActive, isFalse);
    expect(provider.isBusy, isFalse);
    expect(provider.hasMessages, isFalse);
  });

  test('включение подписывает на топик и сохраняет состояние', () async {
    final prefs = await _prefs();
    final service = _FakePushService();
    final provider = PushProvider(prefs, service: service);
    addTearDown(provider.dispose);
    await _settle();

    expect(await provider.setEnabled(true), PushToggleResult.updated);

    expect(service.subscribeCalls, 1);
    expect(provider.isEnabled, isTrue);
    expect(provider.isActive, isTrue);
    expect(provider.isBusy, isFalse);
    expect(prefs.getBool(PushConstants.enabledKey), isTrue);
  });

  test('выданное разрешение не спрашивается повторно', () async {
    final service = _FakePushService();
    final provider = PushProvider(await _prefs(), service: service);
    addTearDown(provider.dispose);
    await _settle();

    expect(await provider.setEnabled(true), PushToggleResult.updated);

    expect(service.permissionRequests, 0);
    expect(service.subscribeCalls, 1);
  });

  test('выключение отписывает от топика', () async {
    final prefs = await _prefs(values: {PushConstants.enabledKey: true});
    final service = _FakePushService();
    final provider = PushProvider(prefs, service: service);
    addTearDown(provider.dispose);
    await _settle();

    expect(provider.isActive, isTrue);

    expect(await provider.setEnabled(false), PushToggleResult.updated);

    expect(service.unsubscribeCalls, 1);
    expect(provider.isActive, isFalse);
    expect(prefs.getBool(PushConstants.enabledKey), isFalse);
  });

  test('без разрешения остаёмся выключенными и не подписываемся', () async {
    final prefs = await _prefs();
    final service = _FakePushService(permissionGranted: false);
    final provider = PushProvider(prefs, service: service);
    addTearDown(provider.dispose);
    await _settle();

    expect(await provider.setEnabled(true), PushToggleResult.permissionDenied);

    expect(service.permissionRequests, 1);
    expect(service.subscribeCalls, 0);
    expect(provider.isActive, isFalse);
    expect(prefs.getBool(PushConstants.enabledKey), isNull);
  });

  test('на устройстве без FCM переключатель неактивен', () async {
    final service = _FakePushService(available: false);
    final provider = PushProvider(await _prefs(), service: service);
    addTearDown(provider.dispose);
    await _settle();

    expect(provider.isAvailable, isFalse);
    expect(provider.isActive, isFalse);
    expect(await provider.setEnabled(true), PushToggleResult.unavailable);
    expect(service.subscribeCalls, 0);
  });

  test('отозванное в системных настройках разрешение выключает переключатель',
      () async {
    final prefs = await _prefs(values: {PushConstants.enabledKey: true});
    final service = _FakePushService(permissionGranted: false);
    final provider = PushProvider(prefs, service: service);
    addTearDown(provider.dispose);
    await _settle();

    // Намерение сохранено, но разрешения нет — уведомления не придут
    expect(provider.isEnabled, isTrue);
    expect(provider.isActive, isFalse);

    service.permissionGranted = true;
    await provider.refreshPermission();

    expect(provider.isActive, isTrue);
  });

test('сообщение при закрытом приложении попадает в очередь', () async {
    final service = _FakePushService(initialMessage: RemoteMessage());
    final provider = PushProvider(await _prefs(), service: service);
    addTearDown(() async {
      provider.dispose();
      await service.close();
    });
    await _settle();

    expect(provider.hasMessages, isTrue);
    expect(provider.takeMessage(), isNotNull);
    expect(provider.hasMessages, isFalse);
    expect(provider.takeMessage(), isNull);
  });

  test('сообщения при открытом приложении и по тапу выстраиваются в очередь',
      () async {
    final service = _FakePushService();
    final provider = PushProvider(await _prefs(), service: service);
    addTearDown(() async {
      provider.dispose();
      await service.close();
    });
    await _settle();

    service.emit(RemoteMessage());
    service.emitOpened(RemoteMessage());
    await _settle();

    expect(provider.hasMessages, isTrue);
    expect(provider.takeMessage(), isNotNull);
    expect(provider.takeMessage(), isNotNull);
    expect(provider.hasMessages, isFalse);
  });
}