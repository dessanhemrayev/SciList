import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scilist/core/constants/update_constants.dart';
import 'package:scilist/data/models/update_info.dart';
import 'package:scilist/data/services/update_service.dart';
import 'package:scilist/presentation/providers/update_provider.dart';

class _FakeUpdateService extends UpdateService {
  _FakeUpdateService(this.update);

  final UpdateInfo? update;
  int checkCalls = 0;

  @override
  Future<String> getCurrentVersion() async => '1.0.0';

  @override
  Future<UpdateInfo?> check() async {
    checkCalls++;
    return update;
  }
}

class _FailingUpdateService extends UpdateService {
  @override
  Future<String> getCurrentVersion() async => '1.0.0';

  @override
  Future<UpdateInfo?> check() async => throw Exception('сеть недоступна');
}

const _update = UpdateInfo(
  version: '1.1.1',
  notes: 'Заметки',
  apkUrl: 'https://example.com/SciList-v1.1.1.apk',
  pageUrl: 'https://example.com/releases/tag/v1.1.1',
);

Future<SharedPreferences> _prefs({Map<String, Object> values = const {}}) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  test('первая проверка при старте возвращает обновление', () async {
    final service = _FakeUpdateService(_update);
    final provider = UpdateProvider(await _prefs(), service: service);

    expect(provider.isCheckDue, isTrue);
    expect(await provider.checkOnStartup(), _update);
    expect(service.checkCalls, 1);
  });

  test('повторная проверка при старте пропускается по таймеру', () async {
    final service = _FakeUpdateService(_update);
    final provider = UpdateProvider(await _prefs(), service: service);

    await provider.checkOnStartup();
    expect(await provider.checkOnStartup(), isNull);
    expect(service.checkCalls, 1);
    expect(provider.isCheckDue, isFalse);
  });

  test('после 6 часов проверка снова выполняется', () async {
    final sixHoursAgo = DateTime.now()
        .subtract(const Duration(hours: 6, minutes: 1))
        .millisecondsSinceEpoch;
    final service = _FakeUpdateService(_update);
    final provider = UpdateProvider(
      await _prefs(values: {UpdateConstants.lastCheckKey: sixHoursAgo}),
      service: service,
    );

    expect(provider.isCheckDue, isTrue);
    expect(await provider.checkOnStartup(), _update);
    expect(service.checkCalls, 1);
  });

  test('пропущенная версия не показывается при старте', () async {
    final service = _FakeUpdateService(_update);
    final provider = UpdateProvider(
      await _prefs(values: {UpdateConstants.skippedVersionKey: '1.1.1'}),
      service: service,
    );

    expect(provider.isSkipped('1.1.1'), isTrue);
    expect(await provider.checkOnStartup(), isNull);
  });

  test('ручная проверка игнорирует таймер', () async {
    final service = _FakeUpdateService(_update);
    final provider = UpdateProvider(await _prefs(), service: service);

    await provider.checkOnStartup();
    final result = await provider.checkForUpdates(force: true);

    expect(result, UpdateCheckResult.updateAvailable);
    expect(service.checkCalls, 2);
  });

  test('пропуск версии сохраняется в preferences', () async {
    final prefs = await _prefs();
    final provider = UpdateProvider(prefs, service: _FakeUpdateService(_update));

    await provider.skipVersion('1.1.1');

    expect(prefs.getString(UpdateConstants.skippedVersionKey), '1.1.1');
    expect(provider.isSkipped('1.1.1'), isTrue);
    expect(provider.isSkipped('1.2.0'), isFalse);
  });

  test('нет обновления — upToDate', () async {
    final provider = UpdateProvider(
      await _prefs(),
      service: _FakeUpdateService(null),
    );

    expect(await provider.checkForUpdates(force: true), UpdateCheckResult.upToDate);
    expect(provider.availableUpdate, isNull);
  });

  test('ошибка сети не ломает проверку — failed', () async {
    final provider = UpdateProvider(await _prefs(), service: _FailingUpdateService());

    expect(await provider.checkForUpdates(force: true), UpdateCheckResult.failed);
    expect(provider.isChecking, isFalse);
  });

  test('после неудачной проверки время не запоминается', () async {
    final service = _FailingUpdateService();
    final provider = UpdateProvider(await _prefs(), service: service);

    expect(await provider.checkForUpdates(force: true), UpdateCheckResult.failed);
    expect(provider.lastCheckAt, isNull);
    // следующий запуск должен проверить сразу, а не через 6 часов
    expect(provider.isCheckDue, isTrue);
  });

  test('после успешной проверки время запоминается', () async {
    final provider = UpdateProvider(await _prefs(), service: _FakeUpdateService(_update));

    expect(await provider.checkForUpdates(force: true), UpdateCheckResult.updateAvailable);
    expect(provider.lastCheckAt, isNotNull);
    expect(provider.isCheckDue, isFalse);
  });

  test('после проверки без обновлений время запоминается', () async {
    final provider = UpdateProvider(await _prefs(), service: _FakeUpdateService(null));

    expect(await provider.checkForUpdates(force: true), UpdateCheckResult.upToDate);
    expect(provider.isCheckDue, isFalse);
  });

  test('время проверки сохраняется', () async {
    final prefs = await _prefs();
    final provider = UpdateProvider(prefs, service: _FakeUpdateService(_update));

    expect(provider.lastCheckAt, isNull);
    await provider.checkForUpdates(force: true);
    expect(provider.lastCheckAt, isNotNull);
    expect(prefs.getInt(UpdateConstants.lastCheckKey), isNotNull);
  });
}