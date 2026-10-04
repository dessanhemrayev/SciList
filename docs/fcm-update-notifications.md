# Push-уведомления о новых релизах (FCM)

> **Статус: план, не реализовано.**
> Сейчас приложение проверяет обновления само: при запуске (не чаще раза в 6 часов) и по кнопке в настройках.
> Этот документ описывает, как добавить push через Firebase Cloud Messaging (FCM).

## Зачем

Проверка при запуске срабатывает только когда пользователь открыл приложение. FCM присылает уведомление сразу после выхода релиза, даже если приложение закрыто.

Цена: зависимость от Firebase и отсутствие push на устройствах без Google Play Services.
Поэтому проверку при запуске **не убираем**, она остаётся запасным вариантом.

## Схема

Пайплайн после создания релиза отправляет сообщение в топик `updates`. Приложение подписано на этот топик. Свой бэкенд и хранение токенов не нужны.

```text
push в master → bump → build → release → [FCM: topic "updates"]
                                                  ↓
                             устройство: уведомление → тап → проверка обновлений
```

## Когда отправлять уведомление

Релиз выходит на каждый push в `master`, но уведомление отправляется **только для значимых изменений**:

- коммиты `feat:` и `fix:` (в том числе со scope, например `fix(ui):`);
- любые коммиты с признаком breaking change (`type!:` или `BREAKING CHANGE`).

Для `chore:`, `docs:`, `refactor:`, `test:`, `ci:` и т. п. релиз и APK создаются как обычно, но push не отправляется. Пользователи увидят такой релиз при следующей проверке при запуске.

Решение принимается в шаге `Bump version` из `release.yml`: он уже разбирает сообщения коммитов. Нужно добавить выходной параметр `notify`:

```bash
if echo "$messages" | grep -qE '^(feat|fix)(\([^)]*\))?!?:|^[a-z]+(\([^)]*\))?!:|BREAKING CHANGE'; then
  echo "notify=true" >> "$GITHUB_OUTPUT"
else
  echo "notify=false" >> "$GITHUB_OUTPUT"
fi
```

Шаг отправки в FCM запускается только при `steps.version.outputs.notify == 'true'`.

Если PR вливается через squash, сообщением коммита становится заголовок PR. Заголовок должен начинаться с `feat:` или `fix:`, иначе уведомление не уйдёт.

## 1. Firebase

1. Создать проект в [Firebase Console](https://console.firebase.google.com/).
2. Добавить Android-приложение с пакетом `com.dessanhemrayev.scilist`.
3. Скачать `google-services.json` и положить в `android/app/`.
4. Ограничить API-ключ в Google Cloud Console (APIs & Services → Credentials) по имени пакета и SHA-1 сертификата подписи.

Про `google-services.json`: файл не секретный, его можно хранить в репозитории. Если не хотите, храните его секретом и записывайте в CI так же, как keystore (см. [android-signing.md](android-signing.md)).
Без файла сборка с плагином Google Services падает.

## 2. Приложение

**Зависимости.** `firebase_core`, `firebase_messaging`. Gradle-плагин `com.google.gms.google-services` подключить в `android/settings.gradle.kts` и `android/app/build.gradle.kts`.

**Разрешение.** Для Android 13+ нужен `POST_NOTIFICATIONS` (манифест и запрос в рантайме). Спрашивайте его не при старте, а когда пользователь включает переключатель «Уведомлять об обновлениях» в настройках.

**Подписка.**

- Включено: `FirebaseMessaging.instance.subscribeToTopic('updates')`.
- Выключено: `unsubscribeFromTopic('updates')`.
- Состояние переключателя хранить в `shared_preferences`.

**Обработка сообщений.**

- `onMessage` (приложение открыто): запустить проверку обновлений и показать диалог.
- `onMessageOpenedApp` и `getInitialMessage` (тап по уведомлению): `checkForUpdates(force: true)` и диалог.

Не доверяйте данным из push (версия, ссылка). По сообщению всегда перезапрашивайте GitHub API: так содержимое уведомления ни на что не влияет, а «Пропустить версию» продолжает работать как раньше.

## 3. Пайплайн

**Секреты** (Settings → Secrets and variables → Actions):

- `FCM_SERVICE_ACCOUNT_JSON`: JSON-ключ сервисного аккаунта.
- `FCM_PROJECT_ID`: идентификатор проекта Firebase.

Сервисный аккаунт создаётся в Google Cloud Console (IAM). Роли достаточно одной: **Firebase Cloud Messaging API Admin**.

**Шаг в `release.yml`** после `Create GitHub Release`, с условием `if: steps.version.outputs.notify == 'true'`:

1. Получить OAuth-токен сервисного аккаунта (например, через `google-github-actions/auth` или скриптом).
2. Отправить сообщение:

```text
POST https://fcm.googleapis.com/v1/projects/<FCM_PROJECT_ID>/messages:send
Authorization: Bearer <токен>
```

```json
{
  "message": {
    "topic": "updates",
    "notification": { "title": "SciList v1.2.0", "body": "Доступно обновление" },
    "data": { "version": "1.2.0" }
  }
}
```

Требования к шагу:

- Выполнять строго **после** создания релиза, иначе пользователь тапнет по уведомлению, а APK ещё не загружен.
- Поставить `continue-on-error: true`: ошибка push не должна делать красным уже выпущенный релиз.

## 4. Нюансы

- Доставка FCM не мгновенная и не гарантирована. Для уведомлений об обновлениях этого достаточно.
- Устройства без Google Play Services не получат push. Для них остаётся проверка при запуске.
- Подписаться на топик может любой клиент, но отправить в него может только владелец сервисного аккаунта.
- Если в одном push-е в `master` объединено несколько коммитов, уведомление уйдёт, когда хотя бы один из них `feat`, `fix` или breaking.

## Порядок работ

1. Firebase-проект и `google-services.json`, убедиться, что приложение собирается.
2. Подписка и обработка сообщений в приложении. Проверить тестовым push из консоли Firebase (Messaging → New campaign → topic `updates`).
3. Выходной параметр `notify` в шаге `Bump version` и шаг отправки в workflow.
4. Переключатель и запрос разрешения в настройках.
5. Сквозная проверка: установить старую версию, выпустить новую через `feat:` (уведомление приходит) и через `chore:` (не приходит), тапнуть, обновиться.
