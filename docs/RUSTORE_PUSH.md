# Пуш-уведомления RuStore

Интеграция пуш-уведомлений через [RuStore Push SDK](https://www.rustore.ru/help/en/sdk/push-notifications/flutter) для приложений, распространяемых в RuStore.

## Условия работы

- На устройстве установлен **RuStore**.
- Пользователь авторизован в RuStore.
- Приложению RuStore разрешена работа в фоне.
- В [RuStore Консоль](https://console.rustore.ru) создан проект пушей и загружены данные приложения (подпись, package name).

## 1. Получение ID проекта

1. Откройте [RuStore Консоль](https://console.rustore.ru).
2. Выберите ваше приложение.
3. Раздел **Push-уведомления** → **Проекты**.
4. Скопируйте **ID проекта**.

Для разных типов сборок (debug/release) с разной подписью может понадобиться отдельный проект в консоли.

## 2. Подстановка ID в приложение

В `android/app/src/main/AndroidManifest.xml` замените плейсхолдер на ваш ID:

```xml
<meta-data
    android:name="ru.rustore.sdk.pushclient.project_id"
    android:value="ВАШ_ID_ПРОЕКТА" />
```

Сейчас в манифесте указано `YOUR_RUSTORE_PUSH_PROJECT_ID` — замените на значение из консоли.

## 3. Отправка токена на бэкенд (по желанию)

Токен сохраняется локально и выводится в лог при отладке. Чтобы отправлять пуши с вашего сервера:

1. В [RuStore Консоль](https://www.rustore.ru/help/en/sdk/general-push-notifications/send-push-notifications) настройте отправку по API (или используйте консольную рассылку).
2. В `lib/services/RustorePushService.dart` в методе `_onTokenReceived` добавьте отправку токена на ваш бэкенд, например:

```dart
static Future<void> _onTokenReceived(String token) async {
  final authToken = await getToken();
  if (authToken == null) return;
  await http.post(
    Uri.parse('$DOMAIN/api/device/push-token'),
    headers: {
      'Authorization': 'Bearer $authToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'token': token, 'platform': 'rustore'}),
  );
}
```

Домен и эндпоинт замените на свои.

## 4. Топики

Подписка/отписка на топики (например, для разделения по типам уведомлений):

```dart
await RustorePushService.subscribeToTopic('news');
await RustorePushService.unsubscribeFromTopic('news');
```

## 5. Проверка доступности

Проверить, доступны ли пуши на устройстве (установлен RuStore и т.д.):

```dart
final ok = await RustorePushService.available();
```

## 6. Как получить push-токен и отправить тестовый пуш

В RuStore **нет отдельного «id устройства»** — для отправки пуша используется **push-токен** (длинная строка, которую выдаёт RuStore SDK).

### Где взять токен (debug-сборка)

1. **Профиль** (нижняя вкладка) → карточка **«Тест пушей RuStore»** вверху списка.
2. Если токена нет — нажмите на карточку (кнопка «запросить»). Токен запросится у RuStore.
3. Если токен есть — нажмите, чтобы скопировать в буфер.
4. **Важно:** RuStore должен быть установлен, вы должны быть в нём авторизованы. Токен на бэкенд отправляется только при входе в приложение (JWT).

Альтернатива: **Профиль → О приложении** — внизу блок с токеном и кнопкой копирования.

### Куда отправить тестовый пуш (не бэкенд)

**Отправка идёт через RuStore Консоль**, не через ваш бэкенд:

1. Откройте [console.rustore.ru](https://console.rustore.ru).
2. Выберите приложение → **Push-уведомления**.
3. Найдите раздел **«Тестовая отправка»** (или «Отправить по токену»).
4. Вставьте скопированный токен.
5. Укажите заголовок и текст → отправьте.

Бэкенд только **сохраняет** токены (POST `/api/climbing-logs/device-push-token`). Отправка пушей с бэкенда — отдельная задача (см. `docs/BACKEND_RUSTORE_PUSH.md`).

### Логи при запуске

При `flutter run` в консоли будет:
```
[RuStore Push] onNewToken: <длинная строка>
```
Скопируйте строку после двоеточия и вставьте в RuStore Консоль.

---

## 7. Открытие по клику и холодный старт

- **Клик по уведомлению** (приложение в фоне/свернуто): обрабатывается в `onMessageOpenedApp` в `RustorePushService.init()`. При необходимости откройте нужный экран по `message.data`.
- **Запуск по уведомлению из закрытого состояния**: используйте `RustorePushClient.getInitialMessage()` (уже вызывается при инициализации). Сообщение можно сохранить и обработать после появления навигации.

## 8. Ошибка «package_id with pub_key doesn't exist»

Если в логах видите:
```
package_id 'com.climbingevents.app' with pub_key 'XX:XX:...' doesn't exist
```

**Причина:** RuStore не знает приложение с этой подписью. В проекте Push нужно добавить отпечаток подписи (SHA-1), которой подписан APK.

**Что сделать:**

1. Узнайте SHA-1 вашего keystore:
   ```bash
   # Debug-сборка (стандартный keystore):
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
   
   # Release (ваш keystore):
   keytool -list -v -keystore path/to/your.keystore -alias your_alias
   ```

2. [RuStore Консоль](https://console.rustore.ru) → ваше приложение → **Push-уведомления** → **Проекты** → выберите проект.

3. Добавьте **отпечаток подписи** (SHA-1) — из вывода keytool или из текста ошибки. Для debug и release обычно нужны разные подписи.

4. Сохраните, подождите несколько минут, пересоберите приложение.

## 9. Ссылки

- [Документация RuStore Push (Flutter)](https://www.rustore.ru/help/en/sdk/push-notifications/flutter)
- [Отправка пушей (API)](https://www.rustore.ru/help/en/sdk/general-push-notifications/send-push-notifications)
- [Пакет flutter_rustore_push на pub.dev](https://pub.dev/packages/flutter_rustore_push)
