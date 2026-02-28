# Backend API: отмена Premium-подписки

Эндпоинт для отмены подписки по запросу пользователя. Подписка остаётся активной до конца оплаченного периода.

---

## POST /api/premium/cancel-subscription

**Headers:** `Authorization: Bearer <token>`  
**Body:**
```json
{
  "cancel_reason": "expensive"
}
```

**Поле `cancel_reason`** (опционально) — причина отмены. Коды для аналитики:

| Код | Описание |
|-----|----------|
| `expensive` | Дорого |
| `rarely_use` | Редко пользуюсь |
| `need_other_features` | Нужны другие функции |
| `temporary_pause` | Временно приостановлю |
| `other` | Другое |
| `prefer_not_say` | Не хочу указывать |

Если поле отсутствует — считать `prefer_not_say`. Сохранить в БД (например, `premium_subscriptions.cancel_reason`) для отчётов по оттоку.

**Назначение:** Пользователь нажал «Отменить подписку» и выбрал причину. Бэкенд помечает подписку как отменённую — она остаётся активной до `subscription_ends_at`.

---

### Response 200

```json
{
  "success": true,
  "subscription_ends_at": "2025-03-15T00:00:00Z",
  "message": "Подписка отменена. Доступ сохранится до 15 марта 2025."
}
```

---

### Response 400 — нет активной подписки

```json
{
  "error": "no_active_subscription",
  "message": "У вас нет активной подписки для отмены"
}
```

---

### Response 400 — подписка уже отменена

```json
{
  "error": "already_cancelled",
  "message": "Подписка уже отменена"
}
```

---

### Response 401

```json
{
  "error": "unauthorized",
  "message": "Требуется авторизация"
}
```

---

## Логика на бэкенде

1. Извлечь `user_id` из токена
2. Найти активную подписку в `premium_subscriptions` (user_id, status = 'active', expires_at > now)
3. Если нет → 400 `no_active_subscription`
4. Если уже `status = 'cancelled'` или `auto_renew = false` → 400 `already_cancelled`
5. Обновить запись: `status = 'cancelled'` (или добавить поле `auto_renew = false`, `cancelled_at = now`)
6. Вернуть 200 с `subscription_ends_at`

---

## Расширение GET /api/premium/status

Добавить поле:

| Поле | Тип | Описание |
|------|-----|----------|
| `subscription_cancelled` | boolean | `true` — пользователь отменил подписку, доступ до конца периода. `false` или отсутствует — подписка активна и будет продлеваться при следующей оплате. |

**Пример response при отменённой подписке:**
```json
{
  "has_active_subscription": true,
  "subscription_ends_at": "2025-03-15T00:00:00Z",
  "subscription_cancelled": true,
  "trial_days_left": 0,
  "trial_started": true
}
```

---

## Таблица premium_subscriptions

Рекомендуемые поля:

| Поле | Тип | Описание |
|------|-----|----------|
| id | int | PK |
| user_id | int | FK |
| started_at | timestamp | Начало подписки |
| expires_at | timestamp | Конец (начало + 30 дней) |
| status | string | `active` — активна; `cancelled` — отменена пользователем |
| order_id | string | Связь с платёжом |
| cancelled_at | timestamp | (Опционально) Когда пользователь нажал «Отменить» |
| cancel_reason | string | (Опционально) Причина: expensive, rarely_use, need_other_features, temporary_pause, other, prefer_not_say |

---

## Чеклист

| # | Задача |
|---|--------|
| 1 | Эндпоинт `POST /api/premium/cancel-subscription` с проверкой Bearer-токена |
| 2 | Проверка: есть активная подписка (expires_at > now) |
| 3 | Обновить status → `cancelled` в `premium_subscriptions` |
| 4 | Вернуть 200 с `subscription_ends_at` |
| 5 | Добавить `subscription_cancelled` в GET /api/premium/status |
| 6 | Принимать `cancel_reason` в body, сохранять для аналитики |
