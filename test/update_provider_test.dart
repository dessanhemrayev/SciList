import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scilist/core/constants/update_constants.dart';
import 'package:scilist/data/models/update_info.dart';
import 'package:scilist/data/services/update_service.dart';
import 'package:scilist/presentation/providers/update_provider.dart';

class _FakeUpdateService extends UpdateService {
  _FakeUpdateService(this.update);

  UpdateInfo? update;
  int checkCalls = 0;
  String? openedApkPath;
  int downloadCalls = 0;

  @override
  Future<String> getCurrentVersion() async => '1.0.0';

  @override
  Future<UpdateInfo?> check() async {
    checkCalls++;
    return update;
  }

  @override
  Future<String> downloadApk(
    UpdateInfo update, {
    required void Function(int received, int total) onReceiveProgress,
    required CancelToken cancelToken,
  }) async {
    downloadCalls++;
    onReceiveProgress(25, 100);
    onReceiveProgress(100, 100);
    return '/tmp/scilist-update-${update.version}.apk';
  }

  @override
  Future<InstallApkResult> openApk(String path) async {
    openedApkPath = path;
    return InstallApkResult.opened;
  }
}

class _ControlledDownloadService extends _FakeUpdateService {
  _ControlledDownloadService() : super(null);

  final started = Completer<void>();
  final response = Completer<String>();

  @override
  Future<String> downloadApk(
    UpdateInfo update, {
    required void Function(int received, int total) onReceiveProgress,
    required CancelToken cancelToken,
  }) {
    downloadCalls++;
    onReceiveProgress(25, 100);
    if (!started.isCompleted) started.complete();
    return Future.any<String>([
      response.future,
      cancelToken.whenCancel.then<String>((_) => throw Exception('cancelled')),
    ]);
  }
}

class _FailingUpdateService extends UpdateService {
  @override
  Future<String> getCurrentVersion() async => '1.0.0';

  @override
  Future<UpdateInfo?> check() async => throw Exception('сеть недоступна');
}

class _ControlledUpdateService extends _FakeUpdateService {
  _ControlledUpdateService() : super(null);

  final response = Completer<UpdateInfo?>();

  @override
  Future<UpdateInfo?> check() {
    checkCalls++;
    return response.future;
  }
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
  for (final result in UpdateCheckResult.values) {
    test('concurrent checks share the future and result: $result', () async {
      final service = _ControlledUpdateService();
      final provider = UpdateProvider(await _prefs(), service: service);
      addTearDown(provider.dispose);

      final first = provider.checkForUpdates(force: true);
      final second = provider.checkForUpdates();
      final forced = provider.checkForUpdates(force: true);

      expect(second, same(first));
      expect(forced, same(first));
      expect(provider.isChecking, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(service.checkCalls, 1);

      if (result == UpdateCheckResult.failed) {
        service.response.completeError(Exception('network unavailable'));
      } else {
        service.response.complete(
          result == UpdateCheckResult.updateAvailable ? _update : null,
        );
      }

      expect(await Future.wait([first, second, forced]), [result, result, result]);
      expect(provider.isChecking, isFalse);
      expect(provider.availableUpdate,
          result == UpdateCheckResult.updateAvailable ? _update : null);
      expect(provider.lastCheckAt,
          result == UpdateCheckResult.failed ? isNull : isNotNull);

      final next = provider.checkForUpdates(force: true);
      expect(next, isNot(same(first)));
      expect(await next, result);
      expect(service.checkCalls, 2);
    });
  }

  test('a listener can join the check when checking starts', () async {
    final service = _ControlledUpdateService();
    final provider = UpdateProvider(await _prefs(), service: service);
    addTearDown(provider.dispose);
    Future<UpdateCheckResult>? listenerCheck;
    provider.addListener(() {
      if (provider.isChecking) {
        listenerCheck = provider.checkForUpdates(force: true);
      }
    });

    final first = provider.checkForUpdates(force: true);
    expect(listenerCheck, same(first));
    await Future<void>.delayed(Duration.zero);
    expect(service.checkCalls, 1);

    service.response.complete(_update);
    expect(await first, UpdateCheckResult.updateAvailable);
  });

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

  test('при запуске из уведомления диалог показывается один раз', () async {
    final service = _FakeUpdateService(_update);
    final provider = UpdateProvider(await _prefs(), service: service);

    // Проверка при старте и проверка по push обе находят релиз,
    // но второй диалог уже не показывается
    expect(await provider.checkOnStartup(), _update);
    expect(await provider.checkFromPush(), isNull);
  });

  test('параллельные проверки при старте и по push делят один запрос', () async {
    final service = _ControlledUpdateService();
    final provider = UpdateProvider(await _prefs(), service: service);
    addTearDown(provider.dispose);

    // Так выглядит реальный запуск из уведомления: обе проверки стартуют
    // в одном кадре и делят один HTTP-запрос
    final startup = provider.checkOnStartup();
    final push = provider.checkFromPush();

    await Future<void>.delayed(Duration.zero);
    expect(service.checkCalls, 1);

    service.response.complete(_update);
    final results = await Future.wait([startup, push]);

    expect(results.whereType<UpdateInfo>(), [_update]);
  });

  test('проверка по push различает сбой сети и отсутствие обновлений', () async {
    final failing = UpdateProvider(await _prefs(), service: _FailingUpdateService());
    final failed = await failing.checkFromPushDetailed();
    expect(failed.result, UpdateCheckResult.failed);
    expect(failed.update, isNull);

    final upToDate = UpdateProvider(
      await _prefs(),
      service: _FakeUpdateService(null),
    );
    final none = await upToDate.checkFromPushDetailed();
    expect(none.result, UpdateCheckResult.upToDate);
    expect(none.update, isNull);
  });

  test('повторная проверка по push находит релиз, вышедший после первой', () async {
    final service = _FakeUpdateService(null);
    final provider = UpdateProvider(await _prefs(), service: service);

    expect((await provider.checkFromPushDetailed()).update, isNull);

    service.update = _update;
    final retry = await provider.checkFromPushDetailed();
    expect(retry.result, UpdateCheckResult.updateAvailable);
    expect(retry.update, _update);
  });

  test('повторный push той же версии не открывает диалог заново', () async {
    final provider = UpdateProvider(
      await _prefs(),
      service: _FakeUpdateService(_update),
    );

    expect(await provider.checkFromPush(), _update);
    expect(await provider.checkFromPush(), isNull);
  });

  test('новая версия после показанной предлагается снова', () async {
    final service = _FakeUpdateService(_update);
    final provider = UpdateProvider(await _prefs(), service: service);

    expect(await provider.checkOnStartup(), _update);

    service.update = const UpdateInfo(
      version: '1.2.0',
      notes: '',
      apkUrl: 'https://example.com/SciList-v1.2.0.apk',
      pageUrl: 'https://example.com/releases/tag/v1.2.0',
    );

    expect(await provider.checkFromPush(), service.update);
  });

  test('ручная проверка показывает версию, даже если диалог уже был', () async {
    final provider = UpdateProvider(
      await _prefs(),
      service: _FakeUpdateService(_update),
    );

    expect(await provider.checkOnStartup(), _update);
    // Пользователь сам нажал кнопку — блокировка на него не распространяется
    expect(
      await provider.checkForUpdates(force: true),
      UpdateCheckResult.updateAvailable,
    );
    expect(provider.availableUpdate, _update);
  });

  test('ручная проверка игнорирует таймер', () async {
    final service = _FakeUpdateService(_update);
    final provider = UpdateProvider(await _prefs(), service: service);

    await provider.checkOnStartup();
    final result = await provider.checkForUpdates(force: true);

    expect(result, UpdateCheckResult.updateAvailable);
    expect(service.checkCalls, 2);
  });

  test('скачивает APK, обновляет прогресс и передаёт файл установщику', () async {
    final service = _FakeUpdateService(_update);
    final provider = UpdateProvider(await _prefs(), service: service);
    addTearDown(provider.dispose);
    final observedProgress = <double?>[];
    provider.addListener(() => observedProgress.add(provider.downloadProgress));

    expect(await provider.downloadUpdate(_update), isTrue);

    expect(provider.isDownloading, isFalse);
    expect(provider.downloadProgress, 1);
    expect(observedProgress, contains(0.25));
    expect(await provider.installDownloadedUpdate(), InstallApkResult.opened);
    expect(service.openedApkPath, '/tmp/scilist-update-1.1.1.apk');
  });

  test('parallel downloads share the same future and file', () async {
    final service = _ControlledDownloadService();
    final provider = UpdateProvider(await _prefs(), service: service);
    addTearDown(provider.dispose);

    final first = provider.downloadUpdate(_update);
    await service.started.future;
    final second = provider.downloadUpdate(_update);

    expect(second, same(first));
    expect(service.downloadCalls, 1);

    service.response.complete('/tmp/scilist-update-1.1.1.apk');
    expect(await Future.wait([first, second]), [true, true]);
  });

  test('cancelling a download waits for it to stop and resets its state', () async {
    final service = _ControlledDownloadService();
    final provider = UpdateProvider(await _prefs(), service: service);
    addTearDown(provider.dispose);

    final download = provider.downloadUpdate(_update);
    await service.started.future;

    await provider.cancelDownload();

    expect(await download, isFalse);
    expect(provider.isDownloading, isFalse);
    expect(service.downloadCalls, 1);
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
