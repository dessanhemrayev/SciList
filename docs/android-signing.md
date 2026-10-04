# Подпись Android-релизов

Релизный APK собирается в GitHub Actions (`.github/workflows/release.yml`) и подписывается постоянным ключом.
Ключ должен быть **одним и тем же** для всех версий: Android не установит обновление поверх приложения, подписанного другим ключом.

Локально (без `android/key.properties`) релиз подписывается debug-ключом, это нормально для разработки.

## 1. Создание keystore

Нужен `keytool` из JDK. Если его нет в `PATH`, он лежит в Android Studio:
`C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`.

```powershell
keytool -genkey -v -keystore upload-keystore.jks -storetype PKCS12 `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Команда спросит пароль и данные сертификата (имя, организация и т. д., можно оставить пустыми).
Запомните:

| Что | Значение |
|-----|----------|
| Файл | `upload-keystore.jks` |
| Alias | `upload` (если не указали `-alias`, то `mykey`) |
| Пароль хранилища | введённый при создании |
| Пароль ключа | для PKCS12 совпадает с паролем хранилища |

Проверить содержимое и посмотреть alias:

```powershell
keytool -list -keystore upload-keystore.jks
```

## 2. Хранение

- **Не кладите `.jks` в репозиторий.** Файлы `*.jks`, `*.keystore` и `key.properties` добавлены в `.gitignore`, но надёжнее хранить ключ вне папки проекта (например, `..\keys\`).
- Сделайте резервную копию файла и паролей (менеджер паролей, зашифрованное хранилище).
- **Потеря ключа = невозможность обновить приложение у существующих пользователей.** Им придётся удалить приложение и поставить заново (данные потеряются).

## 3. Секреты GitHub Actions

Закодируйте keystore в base64 (результат попадёт в буфер обмена):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
```

В репозитории: **Settings → Secrets and variables → Actions → New repository secret**.

| Секрет | Значение |
|--------|----------|
| `ANDROID_KEYSTORE_BASE64` | base64 из буфера обмена |
| `ANDROID_KEYSTORE_PASSWORD` | пароль хранилища |
| `ANDROID_KEY_ALIAS` | alias (`upload`) |
| `ANDROID_KEY_PASSWORD` | пароль ключа; можно не задавать, тогда используется пароль хранилища |

Дополнительно: **Settings → Actions → General → Workflow permissions → Read and write permissions**.
Без этого workflow не сможет запушить коммит с версией, тег и создать релиз.

## 4. Как это работает в сборке

Шаг `Restore keystore` в workflow:

1. Декодирует `ANDROID_KEYSTORE_BASE64` в `android/app/upload-keystore.jks`.
2. Создаёт `android/key.properties` из остальных секретов.
3. `android/app/build.gradle.kts` читает `key.properties` и подписывает release-сборку этим ключом.

Если `ANDROID_KEYSTORE_BASE64` не задан, сборка намеренно падает, чтобы не выпустить APK с debug-подписью.

## 5. Локальная подписанная сборка (по желанию)

Создайте `android/key.properties` (файл в `.gitignore`):

```properties
storePassword=<пароль хранилища>
keyPassword=<пароль ключа>
keyAlias=upload
storeFile=C:/path/to/upload-keystore.jks
```

Затем `flutter build apk --release`.

## 6. Как заменить ключ

Если ключ скомпрометирован или потерян, обновить приложение у текущих пользователей не получится.
Единственный путь: выпустить APK с новым ключом и попросить пользователей удалить старую версию и установить новую.
