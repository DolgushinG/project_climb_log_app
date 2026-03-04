# AI Chat — документация для фронтенда

## Что изменилось (Persistent Memory)

AI-чат теперь сохраняет диалоги и помнит факты о пользователе между сессиями. Чтобы это работало, фронтенд должен сохранять и передавать `conversation_id`.

### Было
- Отправляли `message`, опционально `context` и `history`
- Ответ: `{ "message": { ... } }`

### Стало
- Отправляем `message`, **рекомендуется** `conversation_id` (для продолжения диалога)
- Ответ: `{ "message": { ... }, "conversation_id": 42 }`
- **Нужно сохранять `conversation_id`** (SharedPreferences, AsyncStorage и т.п.) и передавать при следующих запросах

---

## API

### Аутентификация

Те же механизмы, что и для climbing-logs / premium:
- **Bearer token:** `Authorization: Bearer {users.api_token}`
- **Telegram WebApp:** заголовок `x-telegram-init-data`

---

## GET /api/ai/conversations

Список чатов пользователя (чаты про силу, ловкость и т.п.).

**Request**
```
GET /api/ai/conversations
Authorization: Bearer <token>
```

**Response 200**
```json
{
  "conversations": [
    { "id": 42, "title": "Я лазаю 6а...", "created_at": "...", "updated_at": "..." },
    { "id": 41, "title": "Как развить ловкость?", "created_at": "...", "updated_at": "..." }
  ]
}
```

---

## GET /api/ai/conversations/{id}/messages

Сообщения выбранного чата (при открытии диалога).

**Request**
```
GET /api/ai/conversations/{id}/messages
Authorization: Bearer <token>
```

**Response 200**
```json
{
  "conversation_id": 42,
  "title": "Я лазаю 6а...",
  "messages": [
    { "id": 1, "role": "user", "content": "...", "created_at": "..." },
    { "id": 2, "role": "assistant", "content": "...", "created_at": "..." }
  ]
}
```

---

## DELETE /api/ai/conversations/{id}

Удаление чата.

**Request**
```
DELETE /api/ai/conversations/{id}
Authorization: Bearer <token>
```

**Response**
- 204 — успешно удалено
- 404 — чат не найден или уже удалён

---

## POST /api/ai/chat (синхронный чат)

Отправка сообщения и получение ответа.

**Request**
```
POST /api/ai/chat
Content-Type: application/json
Authorization: Bearer <token>
# или
x-telegram-init-data: <initData>
```

**Body**
```json
{
  "message": "Я лазаю 6а, готовлюсь к соревнованиям в Москве",
  "conversation_id": 42
}
```

| Поле | Тип | Обязательно | Описание |
|------|-----|-------------|----------|
| message | string | да | Текст сообщения (max 2000 символов) |
| conversation_id | int | нет | ID диалога. При первом сообщении не передавать; при следующих — передавать значение из предыдущего ответа |
| context | object | нет | Контекст (обычно не нужен — бэкенд подставляет данные из БД) |
| history | array | нет | История сообщений. Игнорируется, если передан `conversation_id` — бэкенд берёт историю из БД |

**Response 200**
```json
{
  "message": {
    "role": "assistant",
    "content": "Отлично! Учитывая твой уровень 6а и подготовку к соревнованиям в Москве...",
    "timestamp": "2025-03-03T12:00:00.000000Z"
  },
  "conversation_id": 42
}
```

**Логика на фронте:**
1. Первый запрос в новом диалоге: отправлять только `message`
2. Сохранить `conversation_id` из ответа
3. Все следующие запросы в этом диалоге: отправлять `message` + `conversation_id`

---

## POST /api/ai/chat/async (асинхронный чат)

Для длительных запросов (polling).

**Request**
```
POST /api/ai/chat/async
Content-Type: application/json
```

**Body**
```json
{
  "message": "Подготовь план тренировок",
  "conversation_id": 42
}
```

Параметры те же, что у синхронного чата.

**Response 202**
```json
{
  "task_id": "chat_01HXYZ...",
  "status": "pending",
  "message": "Сообщение принято. Опрашивайте статус каждые 2–3 секунды."
}
```

**Polling:** `GET /api/ai/chat/async/{task_id}/status`

**Response при completed**
```json
{
  "task_id": "chat_01HXYZ...",
  "status": "completed",
  "result": {
    "message": {
      "role": "assistant",
      "content": "...",
      "timestamp": "2025-03-03T12:00:00.000000Z"
    },
    "conversation_id": 42
  }
}
```

Важно: сохранять `result.conversation_id` и использовать при следующих запросах.

---

## GET /api/ai/memories (опционально)

Просмотр того, что AI запомнил о пользователе. Можно использовать для раздела «Мои данные» или настроек.

**Request**
```
GET /api/ai/memories
Authorization: Bearer <token>
```

**Response 200**
```json
{
  "memories": [
    {
      "id": 1,
      "fact": "Уровень скалолазания: 6а",
      "category": "skill_level",
      "confidence": 0.95,
      "updated_at": "2025-03-03T12:00:00.000000Z"
    },
    {
      "id": 2,
      "fact": "Цель: соревнования в Москве в октябре",
      "category": "goal",
      "confidence": 0.9,
      "updated_at": "2025-03-03T11:30:00.000000Z"
    }
  ]
}
```

**Категории:**
- `skill_level` — уровень, сила, рейтинг
- `goal` — цели, соревнования
- `preference` — предпочтения
- `injury` — травмы, ограничения
- `schedule` — график тренировок
- `equipment` — снаряжение
- `other` — прочее

---

## Коды ошибок

| Код | Значение |
|-----|----------|
| 401 | Не авторизован (нет токена или неверный) |
| 402 | Нет активной Premium-подписки или триала |
| 403 | AI-провайдер не настроен или отключён |
| 404 | `conversation_id` передан, но диалог не найден или принадлежит другому пользователю |
| 503 | Ошибка AI (таймаут, лимиты и т.п.) |

---

## Пример потока (Flutter / любой фреймворк)

```dart
// Сохраняем conversation_id при открытии чата
int? conversationId = await prefs.getInt('ai_conversation_id');

// Отправка сообщения
final response = await http.post(
  '/api/ai/chat',
  body: jsonEncode({
    'message': userMessage,
    if (conversationId != null) 'conversation_id': conversationId,
  }),
);

final data = jsonDecode(response.body);

// Сохраняем для следующих запросов
final newConversationId = data['conversation_id'];
if (newConversationId != null) {
  await prefs.setInt('ai_conversation_id', newConversationId);
}

// Отображаем ответ
final assistantMessage = data['message']['content'];
```

---

## Создание нового диалога

Чтобы начать новый диалог (сбросить контекст):
- Не передавать `conversation_id` при следующем запросе ИЛИ
- Удалить сохранённый `conversation_id` из локального хранилища

После этого бэкенд создаст новый диалог и вернёт новый `conversation_id`.

---

## UX-поток (несколько чатов)

- **Экран 1:** список чатов (`GET /conversations`) + кнопка «Новый чат»
- **Экран 2:** открытый чат с историей (`GET /conversations/{id}/messages`) и полем ввода
- **Новый чат:** первый вопрос задаёт тему, из него формируется `title`
- **Существующий чат:** загрузка истории через `/messages`, отправка с `conversation_id`

Память AI (`user_memories`) общая для всех чатов пользователя. Контекст конкретного диалога (последние сообщения) у каждого чата свой.

---

## Обратная совместимость

- Если не передавать `conversation_id` — всё работает как раньше: создаётся новый диалог
- Поле `conversation_id` в ответе появляется всегда
- Старые клиенты без поддержки `conversation_id` продолжат работать, но AI не будет «помнить» контекст между сессиями

---

## Согласие на обработку данных

При первом входе в AI-чат пользователь выбирает режим: **с памятью** или **без памяти**.

- При смене настроек клиент вызывает **PATCH /api/ai/memory-consent** с `{"ai_memory_consent": true|false}`.
- При открытии экрана при локальном `null` — синхронизация с **GET /api/profile** (поле `ai_memory_consent`).

Подробности — [API_AI_CHAT_CONSENT_BACKEND.md](./API_AI_CHAT_CONSENT_BACKEND.md).
