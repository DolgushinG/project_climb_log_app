# AddToListPending — GET `/api/event/{id}/checkout`

В ответе checkout бэкенд должен возвращать поле **`is_add_to_list_pending`** (boolean).

Используется логика `addToListPending` из event controller: если пользователь добавлен в список ожидания (pending list), в ответе передаётся `"is_add_to_list_pending": true`.

| Поле | Тип | Описание |
|------|-----|----------|
| `is_add_to_list_pending` | `boolean` | `true` — участник в списке ожидания, таймер оплаты не показывается |

---

## Инфо для фронта

- `true` — участник в pending list, **таймер не показывается**
- `false` или отсутствует — обычный checkout, таймер показывается при `remaining_seconds > 0`
