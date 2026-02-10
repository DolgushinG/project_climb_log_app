# Face ID / Touch ID (Passkey) в приложении

Вход, регистрация и удаление Passkey в приложении используют эндпоинты:

**Вход (без токена):**
- **POST** `/api/auth/webauthn/options` — опции (challenge)
- **POST** `/api/auth/webauthn/login` — результат биометрии → `token`

**Регистрация и удаление (с Bearer token):**
- **POST** `/api/profile/webauthn/register/options` — опции для создания Passkey (тело пустое `{}`, заголовок `Authorization: Bearer <token>`)
- **POST** `/api/profile/webauthn/register` — тело: результат `credentials.create()` (id, rawId, type, response.clientDataJSON, response.attestationObject)
- **POST** `/api/profile/webauthn/delete` — удалить все Passkey пользователя (тело не требуется)

---

## Настройка для продакшена

Чтобы Face ID / Touch ID работали на реальных устройствах, нужно связать приложение с доменом (Relying Party).

### iOS (Associated Domains)

1. В Xcode: целевой таргет → **Signing & Capabilities** → **+ Capability** → **Associated Domains**.
2. Добавить домен с префиксом `webcredentials:`:
   - Продакшен: `webcredentials:climbing-events.ru`
   - При необходимости для dev: `webcredentials:climbing-events.ru.tuna.am`
3. На сервере должен быть доступен файл **Apple App Site Association** без расширения:
   - URL: `https://climbing-events.ru/.well-known/apple-app-site-association`
   - Content-Type: `application/json`
   - Пример содержимого (подставьте свой Team ID и bundle ID):
   ```json
   {
     "webcredentials": {
       "apps": ["TEAMID.com.climbingevents.app"]
     }
   }
   ```
4. Bundle ID приложения: см. `ios/Runner/Info.plist` / настройки Xcode (например `com.climbingevents.app`).
5. Проверка: [Apple App Site Association Validator](https://developer.apple.com/help/app-store-connect/configure-app-store-connect/verify-domain-ownership).

### Android (Digital Asset Links)

Ошибка **"RP ID cannot be validated"** на Android означает: домен (rpId) не привязан к приложению. Нужен файл **assetlinks.json** на сервере для каждого домена, с которого идёт запрос (в т.ч. для dev — `climbing-events.ru.tuna.am`).

1. **Узнать SHA256 отпечаток ключа подписи:**
   - **Debug** (при сборке через `flutter run` / debug APK):
     ```bash
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA256
     ```
   - **Release** (ключ из `key.properties`):
     ```bash
     keytool -list -v -keystore path/to/your/keystore.jks -alias your_alias | grep SHA256
     ```
2. **Создать `assetlinks.json`** и выложить на сервер **для каждого домена**:
   - Прод: `https://climbing-events.ru/.well-known/assetlinks.json`
   - Dev: `https://climbing-events.ru.tuna.am/.well-known/assetlinks.json`
   - Content-Type: `application/json`
   - В одном файле можно перечислить несколько отпечатков (debug + release):
   ```json
   [{
     "relation": ["delegate_permission/common.handle_all_urls"],
     "target": {
       "namespace": "android_app",
       "package_name": "com.climbingevents.app",
       "sha256_cert_fingerprints": [
         "AA:BB:CC:...",
         "DD:EE:FF:..."
       ]
     }
   }]
   ```
   Подставьте реальные SHA256 (формат с двоеточиями, одна строка на отпечаток).
3. **Проверка:**
   - Прод: [Digital Asset Links — climbing-events.ru](https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://climbing-events.ru&relation=delegate_permission/common.handle_all_urls)
   - Dev: замените в URL домен на `https://climbing-events.ru.tuna.am`.

### Бэкенд (Laravel)

Ошибка **"Response origin not allowed for this app"** (422 при регистрации) значит: в ответе приложения приходит **origin** в формате Android, а он не в списке разрешённых.

- В `.env` в **WEBAUTHN_ORIGINS** нужно разрешить:
  - веб: `https://climbing-events.ru`, `https://climbing-events.ru.tuna.am`
  - **Android-приложение**: origin приходит как `android:apk-key-hash:<base64>`. Его нужно добавить в список.
- Как узнать origin для Android: один раз залогировать на бэке поле `origin` из разобранного `clientDataJSON` из тела POST `/api/profile/webauthn/register` (или посмотреть в логах Laravel при 422). Либо из ответа приложения в запросе видно в `clientDataJSON` (base64) — после декода там будет `"origin": "android:apk-key-hash:ScrVHA7EBNpyUVwp3PB566P3RrV8ReOZX65SAcrolFs"` (значение зависит от ключа подписи APK).
- Пример значения для текущего debug-сборки (из лога):  
  `android:apk-key-hash:ScrVHA7EBNpyUVwp3PB566P3RrV8ReOZX65SAcrolFs`  
  Для release-сборки будет другой hash — его тоже нужно добавить после первой попытки регистрации с прод-ключом (или вычислить по сертификату).
- Итоговый пример (подставьте актуальные значения):
  ```env
  WEBAUTHN_ORIGINS=https://climbing-events.ru,https://climbing-events.ru.tuna.am,android:apk-key-hash:ScrVHA7EBNpyUVwp3PB566P3RrV8ReOZX65SAcrolFs
  ```
- `WEBAUTHN_ID` должен совпадать с доменом (например `climbing-events.ru`).

---

## Продакшен (release)

Для **release**-сборки (другой ключ подписи) нужно повторить настройку:

1. **Android assetlinks.json** на `https://climbing-events.ru/.well-known/assetlinks.json`: в `sha256_cert_fingerprints` должен быть SHA256 от **релизного** keystore (см. ниже, как получить).
2. **WEBAUTHN_ORIGINS** на прод-бэкенде: добавить origin для релизного APK — он будет вида `android:apk-key-hash:<другая_строка>`.

### Как получить SHA256 для assetlinks.json (прод)

В `assetlinks.json` нужен отпечаток в формате **с двоеточиями** (не base64). Команда (подставь путь к keystore, alias и пароль из `android/key.properties`):

```bash
keytool -list -v -keystore путь/к/upload-keystore.jks -alias upload -storepass ВАШ_PASSWORD | grep SHA256
```

В выводе будет строка вида:
```text
SHA256: A1:B2:C3:D4:E5:...
```

Скопируй **только эту часть** (A1:B2:C3:D4:... без слова SHA256) и подставь в `assetlinks.json` в массив `sha256_cert_fingerprints`. Если где-то был плейсхолдер вроде `REPLACE_WITH_RELEASE_SHA256` — замени его на этот отпечаток. Пример готового фрагмента:

```json
"sha256_cert_fingerprints": [
  "A1:B2:C3:D4:E5:F6:..."
]
```

### Как взять origin для прода (релизного ключа)

**Вариант А — из лога бэкенда (проще):**
- Поставь релизную сборку, в приложении нажми «Добавить Passkey».
- В логе Laravel будет запрос к `POST .../webauthn/register` с телом, в нём поле `clientDataJSON` (base64).
- Декодируй base64 (онлайн или `echo "<строка>" | base64 -d`): внутри JSON будет `"origin": "android:apk-key-hash:XXXX"`.
- Эту строку `android:apk-key-hash:XXXX` целиком добавь в WEBAUTHN_ORIGINS на проде.

**Вариант Б — вычислить по релизному keystore:**
- Origin = `android:apk-key-hash:` + base64url(SHA256(сертификат в DER)).
- В терминале (подставь путь к keystore, alias и пароль):
  ```bash
  echo -n "android:apk-key-hash:"; keytool -exportcert -keystore path/to/release.keystore -alias your_alias -storepass YOUR_PASS | openssl dgst -sha256 -binary | openssl base64 -A | tr '+/' '-_' | tr -d '='
  ```
- Полученную строку добавь в WEBAUTHN_ORIGINS.

**Где в этом проекте взять keystore и alias:**  
Релизная подпись задаётся в `android/key.properties` (файл в .gitignore, не коммитится). Пример формата — `android/key.properties.example`:
- **storeFile** — путь к keystore (от корня проекта), например `upload-keystore.jks` или `android/upload-keystore.jks`.
- **keyAlias** — alias ключа, в примере `upload`.
- Пароль — **storePassword** (и при запросе keytool может понадобиться **keyPassword**).

Путь к файлу keystore: из корня проекта это `./<значение storeFile>`. Например, если `storeFile=upload-keystore.jks`, то полный путь — `путь/до/project_climb_log_app/upload-keystore.jks`. Команда тогда:
  ```bash
  cd /путь/до/project_climb_log_app
  echo -n "android:apk-key-hash:"; keytool -exportcert -keystore ./upload-keystore.jks -alias upload -storepass ВАШ_STORE_PASSWORD | openssl dgst -sha256 -binary | openssl base64 -A | tr '+/' '-_' | tr -d '='
  ```

---

## Где в коде

- **Сервис:** `lib/services/WebAuthnService.dart` — вход (`loginWithPasskey`), регистрация (`registerPasskey`), удаление (`deletePasskeys`).
- **Экран входа:** `lib/login.dart` — кнопка «Войти по Face ID / Touch ID».
- **Настройки авторизации:** `lib/Screens/AuthSettingScreen.dart` — карточка «Face ID / Touch ID (Passkey)»: кнопки «Добавить Passkey» и «Удалить Passkey».

Используется пакет [passkeys](https://pub.dev/packages/passkeys) (Corbado), совместимый с кастомным Relying Party (ваш Laravel бэкенд).
