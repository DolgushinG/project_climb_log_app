# Стоимость подписки из бэкенда

## Изменение GET /api/premium/status

Flutter берёт стоимость подписки из ответа `GET /api/premium/status`. Добавьте поле:

| Поле | Тип | Описание |
|------|-----|----------|
| `subscription_price_rub` | int | Стоимость подписки в рублях (напр. 199). Fallback в приложении: 199 |

**Пример ответа:**
```json
{
  "has_active_subscription": false,
  "trial_days_left": 5,
  "trial_ends_at": "2025-02-20T00:00:00Z",
  "trial_started": true,
  "subscription_ends_at": null,
  "subscription_cancelled": false,
  "subscription_price_rub": 199
}
```

Если поле отсутствует, приложение использует 199 ₽ по умолчанию.
