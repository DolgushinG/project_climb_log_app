# AI Support API для Flutter

API для AI Support (поддержка) в мобильном приложении Flutter. Stateless: история чата хранится на клиенте и передаётся в каждом запросе.

## Базовый URL

```
/api/ai/support/*
```

## Авторизация

**Опциональная.** Если пользователь авторизован — передавайте Bearer token (`Authorization: Bearer {api_token}`). Для гостей — без заголовка.

## Endpoints

### GET /api/ai/support/status

Проверка доступности AI Support. Используйте для показа/скрытия кнопки поддержки.

**Ответ:**
```json
{
  "enabled": true
}
```

---

### POST /api/ai/support/chat

Отправка сообщения в AI Support.

**Запрос:**
```json
{
  "message": "Как оплатить участие?",
  "event_id": 123,
  "page": "checkout",
  "history": [
    {"role": "user", "content": "Здравствуйте", "timestamp": "2025-03-06T10:00:00.000Z"},
    {"role": "assistant", "content": "Здравствуйте! Чем могу помочь?", "timestamp": "2025-03-06T10:00:05.000Z"}
  ]
}
```

| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| message | string | да | Текст сообщения (макс. 2000 символов) |
| event_id | int | нет | ID соревнования |
| page | string | нет | checkout, group-checkout, event, group-register, profile, main, participants, pending, results, other |
| pathname | string | нет | Текущий путь (макс. 500) |
| page_title | string | нет | Заголовок страницы (макс. 300) |
| history | array | нет | История сообщений (пустой массив для нового диалога) |

**Формат history:** каждый элемент — объект `{role: "user"|"assistant", content: string, timestamp?: string}`.

**Ответ:**
```json
{
  "content": "Для оплаты перейдите на страницу checkout...",
  "timestamp": "2025-03-06T10:00:10.000Z",
  "suggested_actions": [
    {"type": "link", "label": "Перейти к оплате", "url": "https://..."}
  ],
  "history": [
    {"role": "user", "content": "Как оплатить?", "timestamp": "..."},
    {"role": "assistant", "content": "Для оплаты...", "timestamp": "..."}
  ]
}
```

**Важно:** сохраняйте `history` из ответа и передавайте при следующем сообщении.

**Ошибки:**
- `403` — AI Support отключён
- `503` — AI сервис недоступен

---

### POST /api/ai/support/event

Трекинг событий (аналитика).

**Запрос:**
```json
{
  "event_type": "modal_open",
  "event_id": 123,
  "page": "checkout",
  "payload": {}
}
```

| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| event_type | string | да | modal_open, action_clicked, session_end |
| event_id | int | нет | ID соревнования |
| page | string | нет | checkout, event и т.д. |
| payload | object | нет | Дополнительные данные |

**Ответ:** `{"ok": true}`

---

### POST /api/ai/support/feedback

Обратная связь на ответ AI (👍 / 👎).

**Запрос:**
```json
{
  "question": "Как оплатить?",
  "response_preview": "Для оплаты перейдите...",
  "response_full": "Полный текст ответа...",
  "rating": "positive",
  "comment": "Очень помогло",
  "event_id": 123
}
```

| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| question | string | да | Текст вопроса (макс. 500) |
| response_preview | string | нет | Превью ответа (макс. 500) |
| response_full | string | нет | Полный текст ответа (макс. 16000) |
| rating | string | да | positive или negative |
| comment | string | нет | Комментарий (макс. 1000) |
| event_id | int | нет | ID соревнования |

**Ответ:** `{"ok": true}`

---

## Rate limit

- chat, event, feedback: ~10 запросов/мин на пользователя или IP
- status: 60 запросов/мин

## suggested_actions

Кнопки под ответом AI. Типы:
- `link` — переход по URL (`label`, `url`)
- `cancel_registration` — отмена регистрации (`label`, `event_id`, `user_id`) — выполнение через API события
