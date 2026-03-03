# API AI-чата (асинхронный)

Спецификация для асинхронного AI-чата по аналогии с планами и тренировками.  
Решает проблему таймаутов при долгом ответе AI.

## Обзор

1. Клиент отправляет сообщение через `POST /api/ai/chat/async`
2. Получает `task_id` сразу (202)
3. Опрашивает `GET /api/ai/chat/async/{task_id}/status` каждые 2–3 сек
4. При `completed` — берёт ответ из `result.message`

## Эндпоинты

### Запуск задачи

```
POST /api/ai/chat/async
```

**Заголовки:** `Authorization: Bearer <token>`

**Тело:** как у синхронного `POST /api/ai/chat`

```json
{
  "message": "Как улучшить вис на одной руке?",
  "context": {},
  "history": [
    {"role": "user", "content": "...", "timestamp": "..."},
    {"role": "assistant", "content": "...", "timestamp": "..."}
  ]
}
```

**Ответ (202):**
```json
{
  "task_id": "chat_abc123xyz",
  "status": "pending",
  "message": "Сообщение принято. Опрашивайте статус каждые 2–3 секунды."
}
```

### Проверка статуса

```
GET /api/ai/chat/async/{task_id}/status
```

(Без trailing slash после `status`.)

**Ответ (200) — в процессе:**
```json
{
  "task_id": "chat_abc123xyz",
  "status": "processing"
}
```

**Ответ (200) — готово:**
```json
{
  "task_id": "chat_abc123xyz",
  "status": "completed",
  "result": {
    "message": {
      "role": "assistant",
      "content": "Текст ответа AI...",
      "timestamp": "2026-03-03T12:00:00.000Z"
    }
  }
}
```

**Ответ (200) — ошибка:**
```json
{
  "task_id": "chat_abc123xyz",
  "status": "failed",
  "error": "Ошибка AI: превышен лимит токенов"
}
```

## Статусы

- `pending` — в очереди
- `processing` — AI генерирует ответ
- `completed` — готово, `result.message` = ChatMessage (role, content, timestamp)
- `failed` — ошибка, `error` = текст

## Рекомендации

- Интервал опроса: 2–3 сек
- Таймаут polling: 2–3 минуты (AI может долго думать)
- При 404 на async — клиент fallback на синхронный `POST /api/ai/chat`
