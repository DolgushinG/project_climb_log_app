# Требования к бэкенду: модуль замеров силы (Strength Tests)

Документ описывает API, которое ожидает Flutter-приложение для работы с замерами силы.

---

## Эндпоинты

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/api/climbing-logs/strength-test-settings` | Вес тела |
| PUT | `/api/climbing-logs/strength-test-settings` | Сохранение веса |
| GET | `/api/climbing-logs/strength-tests` | История замеров |
| POST | `/api/climbing-logs/strength-tests` | Сохранение замера |
| **DELETE** | `/api/climbing-logs/strength-tests/:id` | **Удаление замера по ID** |
| **DELETE** | `/api/climbing-logs/strength-tests?date=YYYY-MM-DD` | **Удаление замера по дате** |
| GET | `/api/climbing-logs/strength-leaderboard` | Рейтинг |

---

## 1. Вес тела

**GET** `/api/climbing-logs/strength-test-settings`

**Response:** `200 OK`
```json
{
  "body_weight": 72.5
}
```

**PUT** `/api/climbing-logs/strength-test-settings`

**Request:**
```json
{
  "body_weight": 72.5
}
```

Валидация: 30–200 кг.

---

## 2. Сохранение замера

**POST** `/api/climbing-logs/strength-tests`

**Request:**
```json
{
  "date": "2025-02-24",
  "body_weight_kg": 72,
  "finger_isometrics": {
    "grip_type": "half_crimp",
    "left_kg": 25,
    "right_kg": 24
  },
  "pinch_40mm_kg": 18,
  "pinch_60mm_kg": 16,
  "pinch_80mm_kg": 14,
  "pulling_power": {
    "added_weight_kg": 15,
    "reps": 1,
    "estimated_1rm_kg": 87,
    "relative_strength_pct": 120.8
  },
  "lock_off_sec": 32,
  "current_rank": "Mountain Lynx",
  "unlocked_badges": ["crab_claws", "hauler"]
}
```

**Response:** `201 Created` или `200 OK`
```json
{
  "id": 123
}
```

Поле `id` обязательно — используется для удаления замера.

**Щипок (pinch):** приложение отправляет три поля на уровне корня:
- `pinch_40mm_kg` — щипок на блоке 40 мм (кг)
- `pinch_60mm_kg` — щипок на блоке 60 мм (кг)
- `pinch_80mm_kg` — щипок на блоке 80 мм (кг)

Все три опциональны. Бэкенд должен сохранять и возвращать все введённые значения.

---

## 3. История замеров

**GET** `/api/climbing-logs/strength-tests`

**Query:**
- `period_days` — 30 | 90 | 365 (по умолчанию 90)
- `test_type` — опционально: `finger` | `pinch` | `pulling`

**Response:** `200 OK`
```json
{
  "tests": [
    {
      "id": 1,
      "date": "2025-02-24",
      "body_weight_kg": 72,
      "finger_left_kg": 25,
      "finger_right_kg": 24,
      "finger_grip_type": "half_crimp",
      "pinch_40mm_kg": 18,
      "pinch_60mm_kg": null,
      "pinch_80mm_kg": null,
      "pulling_added_weight_kg": 15,
      "pulling_relative_strength_pct": 120.8,
      "lock_off_sec": 32
    }
  ]
}
```

**Важно:** приложение парсит поля:
- `id` — обязателен для удаления
- `finger_left_kg`, `finger_right_kg`
- `pinch_40mm_kg`, `pinch_60mm_kg`, `pinch_80mm_kg` — все три сохраняются и отображаются
- `pulling_added_weight_kg`, `pulling_relative_strength_pct`
- `lock_off_sec`
- `body_weight_kg`

---

## 4. Удаление замера (НОВОЕ)

Приложение поддерживает два варианта удаления. Реализовать достаточно один из них.

### Вариант A: по ID

**DELETE** `/api/climbing-logs/strength-tests/:id`

**Пример:** `DELETE /api/climbing-logs/strength-tests/123`

**Response:** `200 OK` или `204 No Content`

**Ошибки:**
- `404 Not Found` — замер не найден или принадлежит другому пользователю

### Вариант B: по дате

**DELETE** `/api/climbing-logs/strength-tests?date=YYYY-MM-DD`

**Пример:** `DELETE /api/climbing-logs/strength-tests?date=2025-02-24`

**Response:** `200 OK` или `204 No Content`

**Логика:** удалить замер текущего пользователя с указанной датой. Если замеров на эту дату несколько — удалить все или первый (на усмотрение бэкенда).

---

## 5. Рейтинг

**GET** `/api/climbing-logs/strength-leaderboard`

**Query:**
- `period` — `week` | `month` | `all`
- `weight_range_kg` — `"60-70"` (диапазон веса)

**Response:** см. `BACKEND_STRENGTH_TESTING.md`

---

## Безопасность

- Все эндпоинты под `Authorization: Bearer <token>`
- Удаление — только свои замеры
- Валидация: `body_weight_kg` 30–200, `block_width_mm` ∈ {40, 60, 80}

---

## Чеклист для бэкенда

- [ ] `POST` принимает `pinch_40mm_kg`, `pinch_60mm_kg`, `pinch_80mm_kg` (все опциональны)
- [ ] `GET` возвращает все три поля щипка в каждом элементе
- [ ] `GET /api/climbing-logs/strength-tests` возвращает `id` в каждом элементе
- [ ] `POST /api/climbing-logs/strength-tests` возвращает `{"id": N}` в ответе
- [ ] `DELETE /api/climbing-logs/strength-tests/:id` — удаление по ID
- [ ] ИЛИ `DELETE /api/climbing-logs/strength-tests?date=YYYY-MM-DD` — удаление по дате
