# API: Премиум-подписка на раздел тренировок

Спецификация для бэкенда — пробный период, статус подписки, оплата через PayAnyWay (MONETA.RU).

---

## 1. Общие данные

- **Оферта:** https://climbing-events.ru/offerta-premium
- **Стоимость:** 199 ₽/месяц
- **Пробный период:** 7 дней (считается с первого входа на страницу тренировок)
- **Платёжная система:** PayAnyWay (MONETA.RU)
  - [SDK Android (PDF)](https://payanyway.ru/info/p/ru/public/merchants/SDKandroid.pdf)
  - [MONETA.Assistant](https://www.moneta.ru/doc/MONETA.Assistant.ru.pdf)
  - [Merchant API](https://www.moneta.ru/doc/MONETA.MerchantAPI.v2.ru.pdf)

### Интеграция SDK в приложении (Android)

Приложение использует нативный PayAnyWay SDK на Android:
- `android/app/src/main/java/ru/integrationmonitoring/monetasdkapp/` — MonetaSdk, MonetaSdkConfig
- `android/app/src/main/assets/` — INI-файлы настроек
- `PayAnyWayActivity` — экран с WebView для платёжной формы

**Настройка:** отредактируйте `android/app/src/main/assets/android_basic_settings.ini`:
- `monetasdk_account_id` — номер расширенного счёта (из личного кабинета MONETA.ru)
- `monetasdk_account_code` — код проверки (если включена подпись)
- `monetasdk_demo_mode` = "1" для тестов, "0" для продакшена
- `monetasdk_test_mode` = "1" для тестовых платежей

---

## 2. Эндпоинты

> **Расширенные требования:** см. [BACKEND_PREMIUM_API_REQUIREMENTS.md](./BACKEND_PREMIUM_API_REQUIREMENTS.md) — `trial_started`, `subscription_ends_at`, `POST /api/premium/start-trial`.

### 2.1 Статус подписки

**`GET /api/premium/status`**

**Headers:** `Authorization: Bearer <token>`

**Response 200:**
```json
{
  "has_active_subscription": false,
  "trial_days_left": 5,
  "trial_ends_at": "2025-02-20T00:00:00Z"
}
```

| Поле | Тип | Описание |
|------|-----|----------|
| `has_active_subscription` | boolean | true — у пользователя активная оплаченная подписка |
| `trial_days_left` | int | Осталось дней пробного периода (0 если пробный истёк или есть подписка) |
| `trial_ends_at` | string (ISO 8601) | Дата окончания пробного периода (опционально) |

**Логика:**
- При первом запросе от пользователя — стартует пробный период (7 дней)
- Если у пользователя уже есть активная подписка — `trial_days_left` может быть 0, `has_active_subscription: true`
- Доступ к разделу тренировок: `has_active_subscription || trial_days_left > 0`

---

### 2.2 Создание платежа

**`POST /api/premium/create-payment`**

**Headers:** `Authorization: Bearer <token>`, `Content-Type: application/json`

**Request body:** `{}` (пустой объект или расширяемый)

**Response 200:**
```json
{
  "payment_url": "https://...",
  "order_id": "premium_12345"
}
```

| Поле | Тип | Описание |
|------|-----|----------|
| `payment_url` | string | URL платёжной формы PayAnyWay — приложение откроет в браузере/WebView |
| `order_id` | string | (опционально) Идентификатор заказа для отслеживания |

**Ошибки:**
- `401` — не авторизован
- `402` — пользователь уже имеет активную подписку
- `500` — ошибка платёжной системы

---

### 2.3 Webhook / Callback от PayAnyWay

Бэкенд должен принимать уведомления о успешной оплате от PayAnyWay.

- PayAnyWay отправляет POST на настроенный URL (success/callback)
- В теле приходят параметры: `order_id`, `MNT_TRANSACTION_ID`, `MNT_OPERATION_ID`, итд
- Бэкенд должен:
  1. Проверить подпись (если включена проверка)
  2. Обновить статус подписки пользователя (привязать к `order_id` → `user_id`)
  3. Активировать подписку на 30 дней
  4. Вернуть success-ответ в формате PayAnyWay

Детали формата callback — в документации [MONETA.MerchantAPI](https://www.moneta.ru/doc/MONETA.MerchantAPI.v2.ru.pdf).

---

### 2.4 Return URL (возврат пользователя после оплаты)

После оплаты пользователь может быть перенаправлен на URL вида:

```
https://climbing-events.ru/premium/success?order_id=...
```

Приложение может обрабатывать deep link или открыть эту страницу в WebView. Желательно:
- На этой странице показать «Оплата прошла успешно»
- Приложение может периодически вызывать `GET /api/premium/status` для обновления статуса

---

## 3. Интеграция PayAnyWay (MONETA.RU)

### 3.1 Регистрация

- Зарегистрироваться в [moneta.ru](https://www.moneta.ru) / PayAnyWay
- Получить `monetasdk_account_id` и `monetasdk_account_code`
- Настроить callback URL для уведомлений об оплате

### 3.2 Создание платежа на бэкенде

Бэкенд не хранит логин/пароль в мобильном приложении. Рекомендуемая схема:

1. Мобильное приложение вызывает `POST /api/premium/create-payment` с Bearer-токеном
2. Бэкенд:
   - Проверяет пользователя по токену
   - Создаёт заказ в своей БД (order_id, user_id, amount=199, status=pending)
   - Вызывает API PayAnyWay / MONETA.Assistant для создания инвойса
   - Получает `payment_url` (ссылку на платёжную форму)
   - Возвращает `payment_url` в ответе
3. Приложение открывает `payment_url` в браузере или WebView
4. Пользователь оплачивает
5. PayAnyWay отправляет callback на бэкенд
6. Бэкенд обновляет подписку пользователя

### 3.3 Параметры для PayAnyWay

- **Сумма:** 199 ₽
- **Валюта:** RUB
- **Описание:** «Premium подписка Climbing Events — 1 месяц (30 дней)»
- **Order ID:** уникальный ID заказа (привязка к user_id на бэке)
- **Success URL:** https://climbing-events.ru/premium/success
- **Fail URL:** https://climbing-events.ru/premium/fail

---

## 4. Модель данных (рекомендация)

| Таблица | Поля |
|--------|------|
| `premium_subscriptions` | id, user_id, started_at, expires_at, status, order_id |
| `premium_orders` | id, user_id, amount, currency, payanyway_order_id, status, created_at |

---

## 5. Зависимости фронта от бэкенда

| Эндпоинт | Статус | Поведение при недоступности |
|----------|--------|-----------------------------|
| `GET /api/premium/status` | Опционально | Fallback на локальный расчёт пробного периода (SharedPreferences) |
| `POST /api/premium/create-payment` | Обязателен для оплаты | Приложение показывает «Платёжная система временно недоступна» |

---

## 6. Оферта и реквизиты

Полный текст оферты: https://climbing-events.ru/offerta-premium

Исполнитель: ИП Долгушин Г.В.
Расчётный счёт: 40802810120000568415
ООО «Банк Точка»
