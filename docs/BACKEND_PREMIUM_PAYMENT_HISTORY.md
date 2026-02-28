# Backend API: история оплат Premium

Эндпоинт для отображения истории платежей пользователя в приложении.

---

## GET /api/premium/payment-history

**Headers:** `Authorization: Bearer <token>`

**Назначение:** Список всех платежей текущего пользователя (успешных и неуспешных). Пользователь видит, когда и сколько он платил.

---

### Response 200

```json
{
  "payments": [
    {
      "order_id": "premium_301_1771095400",
      "amount": 199,
      "currency": "RUB",
      "status": "paid",
      "created_at": "2025-02-13T14:30:00Z",
      "paid_at": "2025-02-13T14:32:15Z"
    },
    {
      "order_id": "premium_301_1770980000",
      "amount": 199,
      "currency": "RUB",
      "status": "paid",
      "created_at": "2025-01-15T10:00:00Z",
      "paid_at": "2025-01-15T10:01:42Z"
    }
  ]
}
```

---

### Поля в объекте платежа

| Поле        | Тип    | Обязательно | Описание |
|-------------|--------|-------------|----------|
| `order_id`  | string | да          | Уникальный ID заказа (для поддержки) |
| `amount`    | number | да          | Сумма в рублях (199) |
| `currency`  | string | нет         | Валюта, по умолчанию `"RUB"` |
| `status`    | string | да          | `paid` — оплачен, `pending` — ожидает оплаты, `failed` — отклонён/ошибка |
| `created_at`| string | да          | ISO 8601 — когда заказ создан |
| `paid_at`   | string | нет         | ISO 8601 — когда оплачен (если status=paid). Можно взять из webhook или обновить при смене status |

---

### Логика на бэкенде

1. Извлечь `user_id` из токена
2. Выбрать из `premium_orders` записи, где `user_id` = текущий пользователь
3. Сортировка: `created_at DESC` (новые сверху)
4. Вернуть список в формате выше

**Фильтрация:** Только заказы текущего пользователя. Никогда не возвращать заказы других пользователей.

---

### Опционально: пагинация

Если ожидается много записей:

**Query params:**
- `limit` — максимум записей (по умолчанию 20)
- `offset` — сдвиг

**Расширенный response:**
```json
{
  "payments": [...],
  "total": 5
}
```

Для MVP пагинация не критична — у пользователя обычно 1–10 платежей.

---

### Response 401

```json
{
  "error": "unauthorized",
  "message": "Требуется авторизация"
}
```

---

### Пустой список

Если платежей нет:
```json
{
  "payments": []
}
```

---

## Связь с существующими таблицами

Данные уже есть в `premium_orders`:

| Поле в БД     | Использование |
|---------------|---------------|
| order_id      | → `order_id` в response |
| user_id       | Фильтр (WHERE user_id = ?) |
| amount        | → `amount` |
| status        | → `status` (pending/paid) |
| created_at    | → `created_at` |

**Дополнительно:** Поле `paid_at` — когда webhook обновил status на `paid`. Если нет — можно использовать `created_at` или время обновления записи. Либо добавить колонку `paid_at` в webhook при смене status.

---

## Пример использования во Flutter

```dart
// GET /api/premium/payment-history
// Отобразить: "13 фев 2025 — 199 ₽", "15 янв 2025 — 199 ₽"
```

---

## Чеклист

| # | Задача |
|---|--------|
| 1 | Эндпоинт `GET /api/premium/payment-history` с проверкой Bearer-токена |
| 2 | Выборка из `premium_orders` по `user_id` |
| 3 | Сортировка по `created_at DESC` |
| 4 | Формат response: `{ "payments": [ { order_id, amount, currency, status, created_at, paid_at? } ] }` |
| 5 | (Опционально) Колонка `paid_at` в БД — заполнять в webhook при status=paid |
