# Push-уведомления о новых релизах (FCM)

> **Статус: реализовано.** Проверка обновлений при запуске осталась: при запуске (не чаще раза в 6 часов) и по кнопке в настройках.
> Push дополняет её: уведомление приходит сразу после выхода релиза, даже если приложение закрыто.

## Зачем

Проверка при запуске срабатывает только когда пользователь открыл приложение. FCM присылает уведомление сразу после выхода релиза.

Цена: зависимость от Firebase и отсутствие push на устройствах без Google Play Services.
Поэтому проверку при запуске **не убираем**, она остаётся запасным вариантом.

## Схема

Пайплайн после создания релиза отправляет сообщение в топик `updates`. Приложение подписано на этот топик. Свой бэкенд и хранение токенов не нужны.

```text
push в master → bump → build → release → [FCM: topic "updates"]
                                                  ↓
                             устройство: уведомление → тап → проверка обновлений
```

Топик задан в двух местах, и они должны совпадать: `PushConstants.topic`
(`lib/core/constants/push_constants.dart`) и топик в `.github/workflows/release.yml`.

## Когда отправлять уведомление

Релиз выходит на каждый push в `master`, но уведомление отправляется **только для значимых изменений**:

- коммиты `feat:` и `fix:` (в том числе со scope, например `fix(ui):`);
- любые коммиты с признаком breaking change (`type!:` или `BREAKING CHANGE`).

Для `chore:`, `docs:`, `refactor:`, `test:`, `ci:` и т. п. релиз и APK создаются как обычно, но push не отправляется. Пользователи увидят такой релиз при следующей проверке при запуске.

Решение принимается в шаге `Bump version` из `release.yml`: он уже разбирает сообщения коммитов. Добавлен выходной параметр `notify`:

```bash
if echo "$messages" | grep -qE '^(feat|fix)(\([^)]*\))?!?:|^[a-z]+(\([^)]*\))?!:|BREAKING CHANGE'; then
  echo "notify=true" >> "$GITHUB_OUTPUT"
else
  echo "notify=false" >> "$GITHUB_OUTPUT"
fi
```

Третья альтернатива — `^[a-z]+(\([^)]*\))?!:` — ловит breaking change у любого типа (`refactor!:`, `chore!:`).
Знак `!` там обязателен, иначе под шаблон попали бы и `chore:`, и `docs:`.

Шаги отправки в FCM запускаются только при `steps.version.outputs.notify == 'true'`.

Если PR вливается через squash, сообщением коммита становится заголовок PR. Заголовок должен начинаться с `feat:` или `fix:`, иначе уведомление не уйдёт.

## 1. Firebase

1. Создать проект в [Firebase Console](https://console.firebase.google.com/).
2. Добавить Android-приложение с пакетом `com.dessanhemrayev.scilist`.
3. Скачать `google-services.json` и положить в `android/app/`.
4. Ограничить API-ключ в Google Cloud Console (APIs & Services → Credentials) по имени пакета и SHA-1 сертификата подписи.

Файл уже лежит в `android/app/google-services.json`, проект Firebase — `scilist-739e7`.
Gradle-плагин `com.google.gms.google-services` подключён в `android/settings.gradle.kts` и `android/app/build.gradle.kts`; **без файла сборка Android падает**.

Про `google-services.json`: файл не секретный, его можно хранить в репозитории (он и лежит в репозитории, `.gitignore` его не трогает). Если не хотите, храните его секретом и записывайте в CI так же, как keystore (см. [android-signing.md](android-signing.md)).

## 2. Приложение

**Зависимости.** `firebase_core`, `firebase_messaging`.

**Разрешение.** Для Android 13+ нужен `POST_NOTIFICATIONS`: объявлен в `android/app/src/main/AndroidManifest.xml` и запрашивается в рантайме.
Спрашивается не при старте, а когда пользователь включает переключатель «Уведомлять об обновлениям» в настройках.

**Подписка.**

- Включено: `FirebaseMessaging.subscribeToTopic('updates')`.
- Выключено: `unsubscribeFromTopic('updates')`.
- Состояние переключателя хранится в `shared_preferences` под ключом `push_updates_enabled`.

**Обработка сообщений.**

- `onMessage` (приложение открыто): запустить проверку обновлений и показать диалог.
- `onMessageOpenedApp` и `getInitialMessage` (тап по уведомлению): `checkForUpdates(force: true)` и диалог.

Не доверяйте данным из push (версия, ссылка). По сообщению всегда перезапрашивается GitHub API: так содержимое уведомления ни на что не влияет, а «Пропустить версию» продолжает работать как раньше — `checkFromPush()` не покажет диалог для версии, которую пользователь уже пропустил.

**Один диалог на версию.** При запуске из уведомления срабатывают две проверки сразу: при старте и по push. Они делят один HTTP-запрос, но оба могли бы показать диалог. Поэтому `UpdateProvider` отдаёт версию под диалог ровно один раз за сессию (`_claimForPrompt`). Ручная проверка в настройках под блокировку не попадает: там пользователь сам попросил показать диалог.

**Иконка уведомления.** По умолчанию FCM берёт иконку приложения, и на части версий Android она рисуется серым квадратом. Своя монохромная иконка задаётся в манифесте:

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@drawable/ic_notification" />
```

**Отозванное разрешение.** Переключатель в настройках сам не узнает, что разрешение отозвали в системных настройках, поэтому при открытии настроек он перечитывает его (`PushProvider.refreshPermission()`).

### Файлы

| Файл | Назначение |
|------|------------|
| `lib/core/constants/push_constants.dart` | Топик и ключ в preferences |
| `lib/data/services/push_service.dart` | Обёртка над FCM: инициализация, подписка, разрешение, потоки сообщений. Все ошибки гасятся |
| `lib/presentation/providers/push_provider.dart` | Состояние переключателя, очередь пришедших сообщений |
| `lib/presentation/widgets/update/update_prompt.dart` | Показывает диалог обновления по push-сообщению |
| `lib/presentation/providers/update_provider.dart` | `checkFromPush()` — проверка по push с игнорированием таймера |

`UpdatePrompt` стоит в `MaterialApp.builder`, то есть выше `Navigator`. Диалог показывается через
`rootNavigatorKey` из `lib/presentation/routes/app_router.dart` (у `MaterialApp.router` параметра
`navigatorKey` нет, ключ задаётся в `GoRouter`).

Сообщения складываются в очередь внутри `PushProvider`: push может прийти раньше, чем подпишется виджет,
— так надёжнее, чем поток, который теряет события без слушателя.

## 3. Пайплайн

**Секреты** (Settings → Secrets and variables → Actions):

- `FCM_SERVICE_ACCOUNT_JSON`: JSON-ключ сервисного аккаунта.
- `FCM_PROJECT_ID`: идентификатор проекта Firebase (`scilist-739e7`).

JSON-ключ лучше сохранить **в одну строку** (minify). GitHub маскирует каждую строку секрета отдельно, и многострочный JSON из-за этого может попасть в действие искажённым.

Сервисному аккаунту нужны **две роли**:

| Роль | Зачем |
|------|-------|
| Firebase Cloud Messaging API Admin | отправка сообщений в топик |
| Service Account Token Creator | выпуск OAuth-токена, на **самом себе** |

Без второй роли шаг `Authenticate in Google Cloud` не сможет выпустить токен.

**Шаги в `release.yml`** после `Create GitHub Release`. У всех `if: steps.version.outputs.notify == 'true'` и `continue-on-error: true`:

1. `Read service account email` достаёт `client_email` из JSON через `jq` — отдельный секрет не нужен, значение не разъедется с ключом.
2. `Authenticate in Google Cloud` (`google-github-actions/auth`):

   ```yaml
   with:
     credentials_json: ${{ secrets.FCM_SERVICE_ACCOUNT_JSON }}
     create_credentials_file: false
     service_account: ${{ steps.service-account.outputs.email }}
     token_format: access_token
   ```

   **`token_format: access_token` обязателен.** Без него выход `auth_token` для ключа сервисного аккаунта — самоподписанный JWT, а FCM v1 требует OAuth access token и отвечает `401`. Токен берётся из `steps.gcp-auth.outputs.access_token`, а не из `auth_token`. Скоуп по умолчанию `cloud-platform` для FCM подходит.
3. `Notify about release` отправляет сообщение:

```text
POST https://fcm.googleapis.com/v1/projects/<FCM_PROJECT_ID>/messages:send
Authorization: Bearer <токен>
```

```json
{
  "message": {
    "topic": "updates",
    "notification": { "title": "SciList v1.2.0", "body": "Доступно обновление v1.2.0" },
    "data": { "version": "v1.2.0" }
  }
}
```

Тег формируется шагом `Bump version` и состоит из цифр и точек, поэтому payload собирается heredoc'ом без `jq`.

**Ошибки push не видны по цвету прогона** — `continue-on-error` оставляет релиз зелёным. Поэтому последний шаг `Report push status` пишет результат в summary прогона: ушло уведомление или нет, и какой именно шаг сломался. Смотреть summary, а не цвет.

Требования к шагам:

- Выполнять строго **после** создания релиза, иначе пользователь тапнет по уведомлению, а APK ещё не загружен.
- `continue-on-error: true`: ошибка push не должна делать красным уже выпущенный релиз.
- Если секреты не заданы, шаг печатает `::warning::` и выходит с кодом 0 — релиз остаётся зелёным.

## 4. Нюансы

- Доставка FCM не мгновенная и не гарантирована. Для уведомлений об обновлениях этого достаточно.
- Устройства без Google Play Services не получат push. Для них остаётся проверка при запуске.
  В настройках переключатель у такого устройства неактивен и подписан «Push-уведомления на этом устройстве недоступны».
- Уведомления выключены по умолчанию: без явного согласия пользователя `POST_NOTIFICATIONS` не запрашивается.
- Подписаться на топик может любой клиент, но отправить в него может только владелец сервисного аккаунта.
- Если в одном push-е в `master` объединено несколько коммитов, уведомление уйдёт, когда хотя бы один из них `feat`, `fix` или breaking.
