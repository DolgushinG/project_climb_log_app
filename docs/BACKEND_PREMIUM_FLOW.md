# Premium: Пошаговый флоу оплаты и что делает бэкенд

## Полный флоу (шаг за шагом)

### Шаг 1. Пользователь нажимает «Оплатить»
Приложение открывает экран оплаты Premium (199 ₽ или 10 ₽ в debug).

---

### Шаг 2. Приложение → POST /api/premium/register-order
**Request:**
```json
{
  "amount": 10,
  "currency": "RUB"
}
```
**Headers:** `Authorization: Bearer <token>`

**Что делает бэкенд:**
1. Проверяет токен, получает `user_id`
2. Генерирует уникальный `order_id` (например: `premium_{user_id}_{timestamp}`)
3. Сохраняет в таблицу `premium_orders`:
   - `order_id`
   - `user_id`
   - `amount`
   - `status` = `pending`
   - `created_at`
4. Возвращает:
```json
{
  "order_id": "premium_301_1771095400",
  "payment_url": "https://service.moneta.ru/assistant.widget?..."
}
```
`payment_url` нужен только для fallback (iOS/браузер). Для Android можно не возвращать — приложение использует нативный SDK.

---

### Шаг 3. Приложение открывает PayAnyWay
Приложение передаёт `order_id` в нативный SDK. PayAnyWay показывает WebView с платёжной формой. Пользователь вводит карту и оплачивает.

---

### Шаг 4. PayAnyWay → POST на webhook (бэкенд)
После успешной оплаты PayAnyWay отправляет запрос на **Pay URL** (указывается в личном кабинете MONETA.ru).

**URL:** `https://climbing-events.ru.tuna.am/premium/webhook/payanyway` (dev)  
**URL:** `https://climbing-events.ru/premium/webhook/payanyway` (prod)

**Параметры (обычно GET или POST):**
- `MNT_TRANSACTION_ID` — это наш `order_id`
- `MNT_OPERATION_ID` — ID операции в PayAnyWay
- `MNT_AMOUNT` — фактическая сумма
- `MNT_SIGNATURE` — подпись (если включена проверка)

**Что делает бэкенд:**
1. Проверить подпись (если `monetasdk_account_code` задан)
2. Взять `MNT_TRANSACTION_ID` (= `order_id`)
3. Найти запись в `premium_orders` по `order_id` → получить `user_id`
4. Обновить `premium_orders`: `status` = `paid`
5. Создать/обновить запись в `premium_subscriptions`:
   - `user_id`
   - `started_at` = сейчас
   - `expires_at` = сейчас + 30 дней
   - `order_id`
6. Вернуть успешный ответ в формате PayAnyWay (см. [MerchantAPI](https://www.moneta.ru/doc/MONETA.MerchantAPI.v2.ru.pdf))

---

### Шаг 5. Редирект пользователя
PayAnyWay перенаправляет пользователя на `climbingevents://premium/success`.  
WebView перехватывает этот URL и закрывает экран оплаты — пользователь оказывается в приложении.

---

### Шаг 6. Приложение обновляет статус
При следующем заходе на вкладку «Тренировки» или при pull-to-refresh приложение вызывает `GET /api/premium/status` и получает `has_active_subscription: true`.

---

## Чеклист для бэкенда

| # | Задача | Статус |
|---|--------|--------|
| 1 | **POST /api/premium/register-order** — принять `amount`, `currency`, сохранить заказ, вернуть `order_id` | |
| 2 | **GET /api/premium/status** — вернуть статус подписки и пробного периода | |
| 3 | **Webhook** — маршрут `/premium/webhook/payanyway`, принять запрос от PayAnyWay | |
| 4 | В webhook: по `MNT_TRANSACTION_ID` найти `user_id`, активировать подписку на 30 дней | |
| 5 | Таблица `premium_orders`: order_id, user_id, amount, status, created_at | |
| 6 | Таблица `premium_subscriptions`: user_id, started_at, expires_at, order_id | |
| 7 | В личном кабинете PayAnyWay указать **Pay URL** = `https://.../premium/webhook/payanyway` | |

---

## Важно

- **Pay URL (webhook)** настраивается **в личном кабинете MONETA.ru**, а не в приложении.
- `order_id` в `register-order` и `MNT_TRANSACTION_ID` в webhook — это одно и то же значение.
- Без связки `order_id` → `user_id` в БД webhook не сможет понять, кому активировать подписку.
