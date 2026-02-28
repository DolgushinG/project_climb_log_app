# Backend API: требования для Premium и пробного периода

Все изменения для корректной работы пробного периода, активации и отображения подписки.

---

## 1. GET /api/premium/status — расширение ответа

**Текущий response:**
```json
{
  "has_active_subscription": false,
  "trial_days_left": 5,
  "trial_ends_at": "2025-02-20T00:00:00Z"
}
```

**Требуемые дополнения:**

| Поле | Тип | Описание |
|------|-----|----------|
| `trial_started` | boolean | `false` — пользователь ещё не нажал «Начать пробный период». `true` — уже активировал (или пробный истёк). Нужно для показа модалки при первом заходе. |
| `subscription_ends_at` | string (ISO 8601) | Дата окончания оплаченной подписки. Для отображения «осталось N дней» в профиле. |

**Пример расширенного response:**
```json
{
  "has_active_subscription": true,
  "trial_days_left": 0,
  "trial_ends_at": null,
  "trial_started": true,
  "subscription_ends_at": "2025-03-15T00:00:00Z"
}
```

**Логика `trial_started`:**
- Новый пользователь (никогда не активировал пробный): `trial_started: false`, `trial_days_left: 0`
- После POST /start-trial: `trial_started: true`, `trial_days_left: 7`, `trial_ends_at: ...`
- Пробный истёк: `trial_started: true`, `trial_days_left: 0`
- Есть подписка: `has_active_subscription: true`, остальное по ситуации

---

## 2. POST /api/premium/start-trial — активация пробного периода

**Эндпоинт:** `POST /api/premium/start-trial`  
**Headers:** `Authorization: Bearer <token>`, `Content-Type: application/json`  
**Body:** `{}`

**Назначение:** Пользователь нажал «Начать» в модалке «7 дней бесплатно». Бэкенд запоминает активацию, чтобы нельзя было использовать пробный период повторно (на другом устройстве/аккаунте).

**Response 200/201:**
```json
{
  "trial_days_left": 7,
  "trial_ends_at": "2025-02-21T00:00:00Z"
}
```

**Response 400** — пробный период уже использован:
```json
{
  "error": "trial_already_used",
  "message": "Пробный период уже был активирован"
}
```

**Логика на бэкенде:**
1. Проверить, что пользователь не активировал пробный ранее (нет записи в БД)
2. Создать запись: `user_id`, `trial_started_at = now`, `trial_ends_at = now + 7 days`
3. Вернуть `trial_days_left: 7`, `trial_ends_at`
4. При повторном вызове — 400

---

## 3. Модель данных (рекомендация)

**Таблица `premium_trials`:**
| Поле | Тип | Описание |
|------|-----|----------|
| id | int | PK |
| user_id | int | FK |
| started_at | timestamp | Время активации |
| ends_at | timestamp | Конец пробного (started_at + 7 дней) |

Уникальный индекс по `user_id` — один пробный период на пользователя.

**Таблица `premium_subscriptions`** (если ещё нет):
| Поле | Тип | Описание |
|------|-----|----------|
| id | int | PK |
| user_id | int | FK |
| started_at | timestamp | Начало подписки |
| expires_at | timestamp | Конец подписки |
| status | string | active/cancelled |

**Отмена подписки:** см. [BACKEND_PREMIUM_CANCEL_SUBSCRIPTION.md](./BACKEND_PREMIUM_CANCEL_SUBSCRIPTION.md) — `POST /api/premium/cancel-subscription`, поле `subscription_cancelled` в status.

---

## 4. Поведение приложения

| Сценарий | Поведение |
|----------|-----------|
| Первый заход, `trial_started: false` | Показать модалку «7 дней бесплатно. Начать?» |
| Нажал «Начать» | POST /start-trial → обновить статус |
| Пробный истекает через ≤3 дней | Баннер в разделе «План»: «Пробный период заканчивается через N дней. Оформить подписку» |
| Подписка оформлена | В профиле: «Подписка. Активна до DD.MM (осталось N дней)» |
| Пробный без подписки | В профиле: «Подписка. Пробный период: N дней» |

---

## 5. Зависимости

- Flutter вызывает `GET /api/premium/status` при загрузке раздела «Тренировки» и профиля
- Flutter вызывает `POST /api/premium/start-trial` только по нажатию «Начать» в модалке
- При недоступности бэкенда — fallback на локальный пробный период (SharedPreferences)
