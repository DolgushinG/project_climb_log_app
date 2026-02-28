# Бэкенд: Премиум-подписка — Чеклист

## 1. API-эндпоинты

### GET /api/premium/status
- **Auth:** Bearer token
- **Ответ:**
```json
{
  "has_active_subscription": false,
  "trial_days_left": 5,
  "trial_ends_at": "2025-02-20T00:00:00Z"
}
```
- Логика: пробный период 7 дней с первого запроса пользователя

### POST /api/premium/register-order — регистрация заказа перед платежом (обязательно для нативного SDK)
- **Auth:** Bearer token
- **Request:** `{"amount": 199, "currency": "RUB"}`
- **Ответ:**
```json
{
  "order_id": "173912345678912"
}
```
- Бэкенд: сгенерировать уникальный `order_id`, сохранить в БД `(order_id, user_id, amount, status=pending)`
- Приложение передаёт этот `order_id` в PayAnyWay. Webhook получит его как `MNT_TRANSACTION_ID` и по нему найдёт `user_id`.

### POST /api/premium/create-payment (для backend-flow, не для нативного SDK)
- **Auth:** Bearer token
- **Request:** `{}`
- **Ответ:** `{"payment_url": "https://...", "order_id": "..."}`
- 402 — если у пользователя уже активная подписка

---

## 2. Webhook PayAnyWay (Pay URL)

**Где настроить:** Личный кабинет MONETA.ru / PayAnyWay → настройки счёта → Pay URL (URL для отчётов об оплате).

**Пример URL:** `https://climbing-events.ru.tuna.am/premium/webhook/payanyway` (dev)  
**Prod:** `https://climbing-events.ru/premium/webhook/payanyway`

- PayAnyWay отправляет POST при успешной оплате
- Параметры: `MNT_TRANSACTION_ID` (= order_id), `MNT_OPERATION_ID`, `MNT_AMOUNT`, подпись (если включена)
- Логика:
  1. Проверить подпись (если monetasdk_account_code задан)
  2. По `MNT_TRANSACTION_ID` найти запись в `premium_orders` → получить `user_id`
  3. Активировать подписку на 30 дней (вставить в `premium_subscriptions`)
  4. Обновить статус заказа: `status=paid`
  5. Вернуть success-ответ в формате PayAnyWay (см. MerchantAPI)

---

## 3. Данные платежа

| Поле | Значение |
|------|----------|
| Сумма | 199 ₽ |
| Валюта | RUB |
| Описание | Premium подписка Climbing Events — 1 месяц (30 дней) |
| Success URL | https://climbing-events.ru/premium/success |
| Fail URL | https://climbing-events.ru/premium/fail |

---

## 4. БД (рекомендация)

- `premium_subscriptions`: user_id, started_at, expires_at, status, order_id
- `premium_orders`: **order_id** (PK, уникальный — MNT_TRANSACTION_ID), user_id, amount, status (pending/paid), created_at

---

## 5. Регистрация PayAnyWay

- Зарегистрироваться на moneta.ru / payanyway.ru
- Получить account_id, account_code
- Настроить callback URL для webhook
