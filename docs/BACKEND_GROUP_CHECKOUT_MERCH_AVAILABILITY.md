# Backend: group-checkout — merch_availability

## Зачем нужно

Чтобы **не давать пользователю выбрать пакет с закончившимся мерчем**, приложение должно получать актуальную доступность и блокировать пакеты заранее. Иначе пользователь выбирает размер и пакет, нажимает «Выбрать», а бэкенд возвращает «Лимит мерча исчерпан» — плохой UX.

## Эндпоинт

`GET /api/event/{id}/group-checkout`

## Поле в ответе

В корне ответа или в `event` должен быть объект **`merch_availability`**:

```json
{
  "merch_availability": {
    "Футболка": {
      "available": 0,
      "limit": 50
    },
    "Кепка": {
      "available": 3,
      "limit": 20
    }
  }
}
```

Или вложено под `event`:

```json
{
  "event": {
    "merch_availability": {
      "Футболка": { "available": 0, "limit": 50 }
    }
  }
}
```

## Структура

| Путь | Тип | Описание |
|------|-----|----------|
| `merch_availability` | object | Ключ — название мерча (как в `event.packages[].merch[].name`) |
| `merch_availability["Название"]` | object | `{ "available": number, "limit": number }` |
| `available` | number | Сколько осталось (0 = закончился, пакет блокируется) |
| `limit` | number | Опционально, лимит (для отображения «осталось: N») |

## Fallback в приложении

Если бэкенд не отдаёт `merch_availability`, приложение пытается собрать его из:

- `event.packages[].merch[].available` / `merch[].limit`
- `event.packages[].merch[].sizes[].available` (сумма по размерам)

Рекомендуется отдавать `merch_availability` на верхнем уровне, как в `checkout`, чтобы UI сразу блокировал недоступные пакеты.
