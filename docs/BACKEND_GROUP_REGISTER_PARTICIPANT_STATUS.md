# Backend: статус участника в групповой регистрации

## Эндпоинт

`GET /api/event/{id}/group-register` — в ответе каждый элемент `related_users[]` должен содержать флаги статуса участия.

## Поля в объекте related_users

| Поле | Тип | Описание |
|------|-----|----------|
| `is_participant` | `boolean` | `true` — участник уже заявлен на это событие (показываем «Уже участвует») |
| или `already_registered` | `boolean` | альтернативное имя того же флага |
| `cannot_participate` | `boolean` | `true` — участник не может быть заявлен (показываем «Не может участвовать») |
| или `participation_blocked` | `boolean` | альтернативное имя того же флага |
| `category_not_suitable` | `boolean` | `true` — категория участника не подходит для события (не даём выбрать) |
| `cannot_participate_reason` | `string` | опционально: причина (показывается в подсказке) |

Фронт проверяет в таком порядке:
1. `is_participant` или `already_registered` → «Уже участвует» (зелёный badge)
2. `cannot_participate` или `participation_blocked` → «Не может участвовать» (оранжевый badge, tooltip из `cannot_participate_reason`)
