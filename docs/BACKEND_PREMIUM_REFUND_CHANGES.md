# Бэкенд: изменения по возврату Premium

Кратко — что изменилось во Flutter и что нужно сделать на бэке.

---

## Что изменилось в приложении

1. **Политика возврата:** Возврат после оплаты не предусмотрен. Пробный период 7 дней — пользователь пробует до оплаты.
2. **UI возврата убран:** Кнопки «Запросить возврат» и статусы возврата в истории платежей удалены.
3. **Приложение больше не вызывает:** `GET /api/premium/refund-preview`, `POST /api/premium/request-refund`.

---

## Что нужно сделать бэкенду

### 1. Упростить GET /api/premium/payment-history

Поля `can_request_refund`, `refund_requested`, `refund_status` больше не нужны в ответе — приложение их не использует.

**Было (если реализовано):**
```json
{
  "payments": [
    {
      "order_id": "...",
      "amount": 199,
      "status": "paid",
      "can_request_refund": false,
      "refund_requested": false,
      "refund_status": null
    }
  ]
}
```

**Нужно теперь:**
```json
{
  "payments": [
    {
      "order_id": "...",
      "amount": 199,
      "currency": "RUB",
      "status": "paid",
      "created_at": "...",
      "paid_at": "..."
    }
  ]
}
```

→ Убрать из response: `can_request_refund`, `refund_requested`, `refund_status`.

---

### 2. Эндпоинты возврата (refund-preview, request-refund)

**Вариант А.** Оставить для внутреннего использования (служба поддержки, админка):
- Пользователь пишет в поддержку «оплатил, но доступ не появился»
- Оператор вручную вызывает API или делает возврат через PayAnyWay
- Логика: возврат только если подписка не активирована (нет записи в `premium_subscriptions` для этого `order_id`)

**Вариант Б.** Удалить эндпоинты, если не используются:
- Обработка возвратов — вручную через PayAnyWay и «Мой налог»

---

### 3. Логика возврата (если оставляете API)

Условие для возврата:
```
order.status = 'paid'
AND NOT exists (SELECT 1 FROM premium_subscriptions WHERE order_id = :order_id)
```

То есть: оплата есть, подписка по этому заказу не создана (webhook не дошёл, сбой) → можно вернуть 100%.

После активации подписки возврат не разрешать.

---

### 4. Ничего не менять в webhook и создании подписок

Текущая логика создания подписки при webhook PayAnyWay остаётся без изменений.

---

## Чеклист для бэкенда

| # | Задача |
|---|--------|
| 1 | Убрать из GET /api/premium/payment-history поля: `can_request_refund`, `refund_requested`, `refund_status` |
| 2 | Решить: оставить refund-preview / request-refund для поддержки или удалить |
| 3 | Если оставить — проверять: возврат только при `status=paid` и отсутствии подписки по order_id |
| 4 | Обновить оферту: «Возврат после оплаты не предусмотрен» (см. docs/PREMIUM_REFUND_POLICY.md) |
