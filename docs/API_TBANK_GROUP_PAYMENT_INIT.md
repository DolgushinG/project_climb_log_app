# T‑Банк: групповая оплата — тело `POST /api/event/{id}/payment/tbank/init`

**Статус:** бэкенд по этому контракту реализован; мобильный клиент шлёт поля ниже из `GroupCheckoutScreen` (`lib/services/tbank_event_payment_service.dart`).

Мобильное приложение для **групповой заявки** отправляет один платёж от пользователя (Bearer), но явно помечает, что это **оплата за группу** и **за каких участников** (по `user_id` из `GET .../group-checkout`).

## Тело запроса (JSON)

| Поле | Тип | Обязательно | Описание |
|------|-----|-------------|----------|
| `scope` | string | да | Для группового сценария с одним плательщиком приложение шлёт `"individual"` (один платёж на заказ). |
| `group_payment` | bool | нет | `true` — признак групповой оплаты (не путать с «один человек без группы»). |
| `participant_user_ids` | int[] | да (клиент всегда шлёт для группы) | Список `user_id` участников группы, по которым **ещё не оплачено** (`is_paid != true` в `group-checkout`). Порядок не важен; дубликаты не шлём. |
| `group_registration_id` | int | нет | Если в ответе `group-checkout` есть идентификатор заявки (`group_registration_id`, `group_id` или `registration_id`), приложение передаёт его для однозначной привязки к сущности на бэкенде. |
| `client_origin` | string | нет (на web — да) | **Только Flutter Web / PWA:** origin SPA, например `https://app.climbing-events.ru` (`Uri.base.origin`). Нужен, чтобы **redirect URL в T‑Банк** (success/fail) строились на **тот же домен**, где открыто приложение. Иначе после оплаты пользователь попадает на другой хост (часто с формой логина), пока в исходной вкладке уже «оплачено». На iOS/Android не передаётся. |

### Пример (группа, веб)

```json
{
  "scope": "individual",
  "group_payment": true,
  "participant_user_ids": [12, 34, 56],
  "group_registration_id": 9001,
  "client_origin": "https://app.climbing-events.ru"
}
```

Индивидуальная оплата на **мобильном** приложении:

```json
{ "scope": "individual" }
```

Индивидуальная оплата на **вебе** — добавляется `client_origin` так же, как в примере выше (без `group_payment`, без `participant_user_ids`, если не группа).

## Семантика (справочно)

1. **Авторизация** — плательщик по **JWT**; права на оплату за эту заявку проверяются на бэкенде.

2. **Сверка состава** — `participant_user_ids` должны совпадать с участниками групповой заявки на событие; иначе 422.

3. **`group_payment` + `scope`** — клиент при группе шлёт `group_payment: true`, `scope: "individual"` и непустой `participant_user_ids`.

4. **`client_origin` (web)** — при создании платежа в T‑Банк подставлять Success/Fail URL с этим origin (или доверенным путём на нём), чтобы редирект после оплаты не уводил на основной сайт без сессии PWA.

5. **Сумма** — по пакетам для переданных `user_id`, в согласии с `group-checkout`.

6. **Заказ** — `order_id` привязан к заявке и платежу; повторный `init` — по политике бэкенда.

7. **После оплаты** — webhook / `payment/tbank/status` → проставление оплаты участникам из списка.

8. **Старые клиенты** — только `{ "scope": "individual" }` (индивидуальный экран или устаревший клиент).

## Связанные эндпоинты в приложении

- `GET /api/event/{id}/group-checkout` — источник `group[]`, `user_id`, `is_paid`, опционально id заявки.  
- `POST /api/event/{id}/payment/tbank/init` — см. выше.  
- `GET /api/event/{id}/payment/tbank/status?order_id=...` — polling после WebView.
