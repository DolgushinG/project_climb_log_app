# Flutter: T‑Банк — `POST /api/event/{event_id}/payment/tbank/init`

ФФД 1.2, СНО, НДС, версия фискализации и прочее **не передаются с клиента** — собирает бэкенд (в т.ч. из `.env`).

Ответ `init` без изменений (`payment_url`, `order_id`, …). Polling `GET .../payment/tbank/status?order_id=` — без изменений.

## Поля тела запроса (дополнительно к уже существующим)

| Поле | Тип | Описание |
|------|-----|----------|
| `send_receipt` | bool | `true` — пользователь хочет фискальный чек от T‑Банка |
| `receipt_email` | string | Опционально; непустая строка, если указан email |
| `receipt_phone` | string | Опционально; телефон (`+7…`, `8…`, `9…` — как принимает бэкенд) |

Если **`send_receipt: true`**, нужен **хотя бы один** контакт: `receipt_email` и/или `receipt_phone`. Иначе **422** с `errors.receipt_email` / `errors.receipt_phone`.

Старый клиент шлёт, например, только `{ "scope": "individual" }` — поведение как раньше; чек в T‑Банк пойдёт только после явного `send_receipt: true` и контакта.

## Примеры JSON

Минимально (без чека), как раньше:

```json
{
  "scope": "individual"
}
```

С фискальным чеком на email:

```json
{
  "scope": "individual",
  "send_receipt": true,
  "receipt_email": "user@example.com"
}
```

С чеком на телефон:

```json
{
  "scope": "individual",
  "send_receipt": true,
  "receipt_phone": "+79001234567"
}
```

Оба контакта (если пользователь заполнил):

```json
{
  "scope": "individual",
  "send_receipt": true,
  "receipt_email": "user@example.com",
  "receipt_phone": "+79001234567"
}
```

Групповая оплата — те же поля чека, плюс существующие поля группы (`group_payment`, `participant_user_ids`, …).

## Реализация во Flutter

- Сервис: `lib/services/tbank_event_payment_service.dart` — параметры `sendReceipt`, `receiptEmail`, `receiptPhone`; в JSON попадают только при `sendReceipt == true`.
- UI: `lib/widgets/tbank_fiscal_receipt_block.dart`; экраны `CheckoutScreen`, `GroupCheckoutScreen` — переключатель и поля, локальная проверка «хотя бы один контакт», подстановка email/телефона из `GET /api/profile` (`email`, `contact`).
- Ошибки **422**: разбор `message` и при необходимости первых сообщений в `errors.receipt_email` / `errors.receipt_phone`.
